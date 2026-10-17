import Foundation

/// Owns the single cloud MQTT connection, subscribes to every printer topic and
/// fans reports out to the matching `PrinterService`.
@MainActor
final class BambuCloud: ObservableObject {
    @Published private(set) var connected = false

    var onReport: ((String, [String: Any]) -> Void)?
    var onAuthFailure: (() -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private var client: MQTTClient?
    private var session: CloudSession?
    private var serials: [String] = []
    private var sequence = 0
    private var lastPushall: [String: Date] = [:]

    func start(session: CloudSession, serials: [String]) {
        stop()
        self.session = session
        self.serials = serials
        guard !serials.isEmpty else { return }

        let client = MQTTClient(config: .init(
            host: session.region.mqttHost,
            port: 8883,
            username: "u_\(session.uid)",
            password: session.accessToken,
            clientID: Self.stableClientID(),
            keepAlive: 60,
            allowInsecureTLS: false
        ))
        client.onConnected = { [weak self] in
            Task { @MainActor in self?.handleConnected() }
        }
        client.onDisconnected = { [weak self] reason in
            Task { @MainActor in
                self?.setConnected(false)
                Log.write("Cloud disconnected: \(reason)")
            }
        }
        client.onAuthFailure = { [weak self] in
            Task { @MainActor in self?.onAuthFailure?() }
        }
        client.onMessage = { [weak self] topic, data in
            Task { @MainActor in self?.handleMessage(topic: topic, data: data) }
        }
        self.client = client

        for serial in serials {
            client.subscribe("device/\(serial)/report")
        }
        client.start()
        Log.write("Cloud starting for \(serials.count) printer(s), uid=\(session.uid)")
    }

    func stop() {
        client?.stop()
        client = nil
        session = nil
        serials = []
        setConnected(false)
    }

    func send(serial: String, body: [String: Any]) {
        guard let client else {
            Log.write("Cannot send command: MQTT not started")
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        client.publish(topic: "device/\(serial)/request", payload: data, qos: 1)
        if let text = String(data: data, encoding: .utf8) {
            Log.write("TX \(serial): \(text)")
        }
    }

    func requestPushall(serial: String, force: Bool = false) {
        if !force, let last = lastPushall[serial],
           Date().timeIntervalSince(last) < 2.0 {
            return
        }
        lastPushall[serial] = Date()
        sequence += 1
        send(serial: serial, body: [
            "pushing": [
                "sequence_id": String(sequence),
                "command": "pushall",
                "version": 1,
                "push_target": 1
            ]
        ])
    }

    private static func stableClientID() -> String {
        let key = "mqttClientID"
        if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty {
            return saved
        }
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        let id = "bambubar_\(suffix)"
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    // MARK: - Private

    private func handleConnected() {
        setConnected(true)
        for serial in serials {
            requestPushall(serial: serial, force: true)
        }
    }

    private func setConnected(_ value: Bool) {
        guard connected != value else { return }
        connected = value
        onConnectionChanged?(value)
    }

    private func handleMessage(topic: String, data: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }
        let parts = topic.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return }
        let serial = parts[1]
        if let print = json["print"] as? [String: Any] {
            onReport?(serial, print)
        }
        if json["print"] == nil, json["info"] != nil {
            // Command acknowledgement, no status to merge.
        }
    }
}
