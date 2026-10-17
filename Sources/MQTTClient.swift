import Foundation
import Network
import Security

/// Small MQTT 3.1.1 client with just the pieces BambuBar needs:
/// TLS connect, subscribe, publish (QoS 0), keepalive and reconnects.
final class MQTTClient {
    struct Config {
        var host: String
        var port: UInt16 = 8883
        var username: String
        var password: String
        var clientID: String
        var keepAlive: UInt16 = 60
        var allowInsecureTLS: Bool = false
    }

    var onConnected: (() -> Void)?
    var onDisconnected: ((String) -> Void)?
    var onMessage: ((String, Data) -> Void)?
    var onAuthFailure: (() -> Void)?

    private let config: Config
    private let queue = DispatchQueue(label: "com.local.bambubar.mqtt")
    private var connection: NWConnection?
    private var buffer: [UInt8] = []
    private var subscriptions = Set<String>()
    private var pendingPublishes: [(String, Data)] = []
    private var shouldRun = false
    private var ready = false
    private var packetID: UInt16 = 1
    private var pingTimer: DispatchSourceTimer?
    private var reconnectWork: DispatchWorkItem?
    private var backoff: TimeInterval = 2
    private var lastInbound = Date()
    private var didNotifyDisconnect = false

    init(config: Config) {
        self.config = config
    }

    func start() {
        queue.async {
            guard !self.shouldRun else { return }
            self.shouldRun = true
            self.open()
        }
    }

    func stop() {
        queue.async {
            self.shouldRun = false
            self.reconnectWork?.cancel()
            self.reconnectWork = nil
            self.stopPing()
            self.ready = false
            self.connection?.stateUpdateHandler = nil
            self.connection?.cancel()
            self.connection = nil
            self.buffer.removeAll()
        }
    }

    func subscribe(_ topic: String) {
        queue.async {
            self.subscriptions.insert(topic)
            if self.ready { self.sendSubscribe([topic]) }
        }
    }

    func publish(topic: String, payload: Data) {
        queue.async {
            if self.ready {
                self.sendPublish(topic: topic, payload: payload)
            } else {
                self.pendingPublishes.append((topic, payload))
                if self.pendingPublishes.count > 30 { self.pendingPublishes.removeFirst() }
            }
        }
    }

    var isReady: Bool {
        queue.sync { ready }
    }

    // MARK: - Connection

    private func open() {
        guard shouldRun else { return }
        reconnectWork?.cancel()
        reconnectWork = nil
        stopPing()
        ready = false
        buffer.removeAll()
        didNotifyDisconnect = false

        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 10
        tcp.noDelay = true
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        if config.allowInsecureTLS {
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in
                complete(true)
            }, queue)
        }

        let params = NWParameters(tls: tls, tcp: tcp)
        params.allowLocalEndpointReuse = true
        let conn = NWConnection(host: NWEndpoint.Host(config.host),
                                port: NWEndpoint.Port(rawValue: config.port) ?? 8883,
                                using: params)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Log.write("MQTT transport ready \(self.config.host):\(self.config.port)")
                self.lastInbound = Date()
                self.sendConnect()
                self.receiveLoop()
            case .waiting(let error):
                Log.write("MQTT waiting: \(error.localizedDescription)")
            case .failed(let error):
                self.handleDrop("连接失败：\(error.localizedDescription)")
            case .cancelled:
                if self.shouldRun { self.scheduleReconnect() }
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func handleDrop(_ reason: String) {
        guard shouldRun else { return }
        ready = false
        stopPing()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        if !didNotifyDisconnect {
            didNotifyDisconnect = true
            let cb = onDisconnected
            DispatchQueue.main.async { cb?(reason) }
        }
        Log.write("MQTT dropped: \(reason)")
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        reconnectWork?.cancel()
        let delay = backoff
        backoff = min(backoff * 2, 30)
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.shouldRun else { return }
            self.open()
        }
        reconnectWork = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
        Log.write("MQTT reconnect in \(Int(delay))s")
    }

    private func startPing() {
        stopPing()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 20, repeating: 20)
        timer.setEventHandler { [weak self] in
            guard let self, self.ready else { return }
            if Date().timeIntervalSince(self.lastInbound) > 120 {
                self.handleDrop("心跳超时")
                return
            }
            self.send([0xC0, 0x00])
        }
        timer.resume()
        pingTimer = timer
    }

    private func stopPing() {
        pingTimer?.cancel()
        pingTimer = nil
    }

    // MARK: - Packets

    private func send(_ bytes: [UInt8]) {
        guard let connection else { return }
        connection.send(content: Data(bytes), completion: .contentProcessed { [weak self] error in
            if let error {
                Log.write("MQTT send error: \(error.localizedDescription)")
                self?.handleDrop("发送失败")
            }
        })
    }

    private func nextPacketID() -> UInt16 {
        packetID = packetID == UInt16.max ? 1 : packetID + 1
        return packetID
    }

    private func sendConnect() {
        var payload: [UInt8] = []
        payload.append(contentsOf: Self.mqttString(config.clientID))
        payload.append(contentsOf: Self.mqttString(config.username))
        payload.append(contentsOf: Self.mqttString(config.password))

        var variable: [UInt8] = []
        variable.append(contentsOf: Self.mqttString("MQTT"))
        variable.append(4) // protocol level 3.1.1
        variable.append(0xC2) // clean session + username + password
        variable.append(contentsOf: [UInt8(config.keepAlive >> 8), UInt8(config.keepAlive & 0xFF)])
        variable.append(contentsOf: payload)

        var packet: [UInt8] = [0x10]
        packet.append(contentsOf: Self.remainingLength(variable.count))
        packet.append(contentsOf: variable)
        lastInbound = Date()
        send(packet)
    }

    private func sendSubscribe(_ topics: [String]) {
        guard !topics.isEmpty else { return }
        let pid = nextPacketID()
        var payload: [UInt8] = [UInt8(pid >> 8), UInt8(pid & 0xFF)]
        for topic in topics {
            payload.append(contentsOf: Self.mqttString(topic))
            payload.append(0) // QoS 0
        }
        var packet: [UInt8] = [0x82]
        packet.append(contentsOf: Self.remainingLength(payload.count))
        packet.append(contentsOf: payload)
        send(packet)
    }

    private func sendPublish(topic: String, payload: Data) {
        var body: [UInt8] = []
        body.append(contentsOf: Self.mqttString(topic))
        body.append(contentsOf: [UInt8](payload))
        var packet: [UInt8] = [0x30]
        packet.append(contentsOf: Self.remainingLength(body.count))
        packet.append(contentsOf: body)
        send(packet)
    }

    private static func mqttString(_ string: String) -> [UInt8] {
        let utf8 = Array(string.utf8)
        var out: [UInt8] = [UInt8((utf8.count >> 8) & 0xFF), UInt8(utf8.count & 0xFF)]
        out.append(contentsOf: utf8)
        return out
    }

    private static func remainingLength(_ length: Int) -> [UInt8] {
        var value = length
        var out: [UInt8] = []
        repeat {
            var digit = UInt8(value % 128)
            value /= 128
            if value > 0 { digit |= 0x80 }
            out.append(digit)
        } while value > 0
        return out
    }

    // MARK: - Receive

    private func receiveLoop() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lastInbound = Date()
                self.buffer.append(contentsOf: data)
                self.processBuffer()
            }
            if let error {
                self.handleDrop("接收失败：\(error.localizedDescription)")
                return
            }
            if isComplete {
                self.handleDrop("连接被关闭")
                return
            }
            if self.shouldRun {
                self.receiveLoop()
            }
        }
    }

    private func processBuffer() {
        while buffer.count >= 2 {
            let header = buffer[0]
            let type = header >> 4

            var multiplier = 1
            var length = 0
            var index = 1
            var complete = false
            while index < buffer.count {
                let byte = Int(buffer[index])
                length += (byte & 0x7F) * multiplier
                multiplier *= 128
                index += 1
                if byte & 0x80 == 0 { complete = true; break }
                if index > 4 { break }
            }
            guard complete else { return }
            guard buffer.count >= index + length else { return }

            let packet = Array(buffer[index..<(index + length)])
            buffer.removeFirst(index + length)

            switch type {
            case 2: // CONNACK
                handleConnack(packet)
            case 3: // PUBLISH
                handlePublish(header: header, packet: packet)
            case 13: // PINGRESP
                break
            default:
                break
            }
        }
    }

    private func handleConnack(_ packet: [UInt8]) {
        guard packet.count >= 2 else { return }
        let code = packet[1]
        if code == 0 {
            ready = true
            backoff = 2
            lastInbound = Date()
            Log.write("MQTT connected")
            if !subscriptions.isEmpty {
                sendSubscribe(Array(subscriptions))
            }
            for (topic, payload) in pendingPublishes {
                sendPublish(topic: topic, payload: payload)
            }
            pendingPublishes.removeAll()
            startPing()
            let cb = onConnected
            DispatchQueue.main.async { cb?() }
        } else {
            Log.write("MQTT CONNACK refused: \(code)")
            if code == 4 || code == 5 {
                shouldRun = false
                let cb = onAuthFailure
                DispatchQueue.main.async { cb?() }
            }
            handleDrop("MQTT 拒绝连接（\(code)）")
        }
    }

    private func handlePublish(header: UInt8, packet: [UInt8]) {
        let qos = (header >> 1) & 0x03
        guard packet.count >= 2 else { return }
        let topicLength = Int(packet[0]) << 8 | Int(packet[1])
        guard packet.count >= 2 + topicLength else { return }
        let topic = String(bytes: packet[2..<(2 + topicLength)], encoding: .utf8) ?? ""
        var offset = 2 + topicLength
        if qos > 0 {
            guard packet.count >= offset + 2 else { return }
            let pid = UInt16(packet[offset]) << 8 | UInt16(packet[offset + 1])
            offset += 2
            send([0x40, 0x02, UInt8(pid >> 8), UInt8(pid & 0xFF)])
        }
        guard packet.count >= offset else { return }
        let payload = Data(packet[offset...])
        let cb = onMessage
        DispatchQueue.main.async { cb?(topic, payload) }
    }
}
