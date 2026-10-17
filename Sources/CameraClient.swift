import Foundation
import AppKit
import Network
import Security

/// Pulls the A1/P1 MJPEG stream from the printer's TLS port 6000.
/// The stream is a sequence of 16-byte headers followed by JPEG bytes.
final class CameraClient: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var connected = false
    @Published private(set) var errorText: String?

    private let queue = DispatchQueue(label: "com.local.bambubar.camera")
    private var connection: NWConnection?
    private var buffer: [UInt8] = []
    private var running = false
    private var host = ""
    private var accessCode = ""
    private var lastFrameAt = Date()
    private var lastImageAt = Date.distantPast
    private var watchdog: DispatchSourceTimer?
    private var reconnectWork: DispatchWorkItem?

    func start(host: String, accessCode: String) {
        guard !host.isEmpty, !accessCode.isEmpty else {
            errorText = Lang.t("缺少打印机 IP 或访问码", "Missing printer IP or access code")
            return
        }
        if running, self.host == host, self.accessCode == accessCode { return }
        stop()
        self.host = host
        self.accessCode = accessCode
        running = true
        errorText = nil
        queue.async { [weak self] in self?.open() }
    }

    func stop() {
        running = false
        queue.async { [weak self] in
            guard let self else { return }
            self.reconnectWork?.cancel()
            self.reconnectWork = nil
            self.watchdog?.cancel()
            self.watchdog = nil
            self.connection?.stateUpdateHandler = nil
            self.connection?.cancel()
            self.connection = nil
            self.buffer.removeAll()
            DispatchQueue.main.async {
                self.connected = false
            }
        }
    }

    // MARK: - Connection

    private func open() {
        guard running else { return }
        reconnectWork?.cancel()
        reconnectWork = nil
        buffer.removeAll()

        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 8
        tcp.noDelay = true
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in
            complete(true)
        }, queue)
        let params = NWParameters(tls: tls, tcp: tcp)
        let conn = NWConnection(host: NWEndpoint.Host(host), port: 6000, using: params)
        connection = conn
        lastFrameAt = Date()

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Log.write("Camera connected \(self.host):6000")
                self.sendAuth()
                DispatchQueue.main.async {
                    self.connected = true
                    self.errorText = nil
                }
                self.receiveLoop()
                self.startWatchdog()
            case .failed(let error):
                self.fail(Lang.t("连接失败：\(error.localizedDescription)", "Connection failed: \(error.localizedDescription)"))
            case .waiting(let error):
                Log.write("Camera waiting: \(error.localizedDescription)")
            case .cancelled:
                if self.running { self.scheduleReconnect() }
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func sendAuth() {
        var packet = [UInt8](repeating: 0, count: 80)
        func put(_ value: UInt32, _ offset: Int) {
            packet[offset] = UInt8(value & 0xFF)
            packet[offset + 1] = UInt8((value >> 8) & 0xFF)
            packet[offset + 2] = UInt8((value >> 16) & 0xFF)
            packet[offset + 3] = UInt8((value >> 24) & 0xFF)
        }
        put(0x40, 0)
        put(0x3000, 4)
        put(0, 8)
        put(0, 12)
        let user = Array("bblp".utf8)
        for (i, b) in user.enumerated() where i < 32 { packet[16 + i] = b }
        let code = Array(accessCode.utf8)
        for (i, b) in code.enumerated() where i < 32 { packet[48 + i] = b }

        connection?.send(content: Data(packet), completion: .contentProcessed { error in
            if let error { Log.write("Camera auth send error: \(error.localizedDescription)") }
        })
    }

    private func receiveLoop() {
        guard let connection, running else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(contentsOf: data)
                self.processFrames()
            }
            if let error {
                self.fail(Lang.t("画面中断：\(error.localizedDescription)", "Camera stream interrupted: \(error.localizedDescription)"))
                return
            }
            if isComplete {
                self.fail(Lang.t("画面连接被关闭", "Camera connection closed"))
                return
            }
            if self.running { self.receiveLoop() }
        }
    }

    private func processFrames() {
        while buffer.count >= 16 {
            let size = Int(buffer[0])
                | (Int(buffer[1]) << 8)
                | (Int(buffer[2]) << 16)
                | (Int(buffer[3]) << 24)
            if size <= 0 {
                buffer.removeFirst(16)
                continue
            }
            guard size < 8_000_000 else {
                Log.write("Camera frame too large (\(size)); resetting buffer")
                buffer.removeAll()
                fail(Lang.t("画面数据异常", "Unexpected camera data"))
                return
            }
            guard buffer.count >= 16 + size else { return }
            let jpeg = Array(buffer[16..<(16 + size)])
            buffer.removeFirst(16 + size)
            guard jpeg.count > 4, jpeg[0] == 0xFF, jpeg[1] == 0xD8, jpeg[jpeg.count - 2] == 0xFF, jpeg[jpeg.count - 1] == 0xD9 else {
                continue
            }
            lastFrameAt = Date()
            let now = Date()
            guard now.timeIntervalSince(lastImageAt) >= 0.3 else { continue }
            lastImageAt = now
            if let img = NSImage(data: Data(jpeg)) {
                DispatchQueue.main.async {
                    self.image = img
                    self.connected = true
                    self.errorText = nil
                }
            }
        }
    }

    private func startWatchdog() {
        watchdog?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self, self.running else { return }
            if Date().timeIntervalSince(self.lastFrameAt) > 25 {
                self.fail(Lang.t("等待画面超时", "Timed out waiting for a frame"))
            }
        }
        timer.resume()
        watchdog = timer
    }

    private func fail(_ message: String) {
        guard running else { return }
        Log.write("Camera: \(message)")
        DispatchQueue.main.async {
            self.connected = false
            self.errorText = message
        }
        watchdog?.cancel()
        watchdog = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard running else { return }
        reconnectWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.running else { return }
            self.open()
        }
        reconnectWork = work
        queue.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
