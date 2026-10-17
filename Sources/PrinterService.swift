import Foundation

@MainActor
final class PrinterService: ObservableObject, Identifiable {
    private(set) var device: CloudDevice
    @Published private(set) var status = PrinterStatus()
    @Published private(set) var isOnline = false
    @Published private(set) var lastCommandAt: Date?

    /// (newStatus, oldState, newState)
    var onStateTransition: ((PrinterStatus, PrintState, PrintState) -> Void)?
    var sendHandler: ((String, [String: Any]) -> Void)?

    private var sequence = 0

    var id: String { device.serial }

    init(device: CloudDevice) {
        self.device = device
        self.isOnline = device.online
    }

    func ingest(print: [String: Any]) {
        let oldState = status.state
        let oldOnline = isOnline
        status.apply(report: print)
        if !oldOnline { isOnline = true }
        if oldState != status.state, status.state == .finished || status.state == .failed {
            onStateTransition?(status, oldState, status.state)
        }
        if !isOnline { isOnline = true }
    }

    func updateDevice(_ newDevice: CloudDevice) {
        device = newDevice
        if newDevice.online, status.lastUpdate == nil {
            isOnline = true
        }
    }

    func setDemoStatus(_ value: PrinterStatus, online: Bool = true) {
        status = value
        isOnline = online
    }

    func markOfflineIfStale(now: Date = Date()) {
        guard let last = status.lastUpdate else {
            if device.online { isOnline = true } else { isOnline = false }
            return
        }
        if now.timeIntervalSince(last) > 150 {
            isOnline = false
        }
    }

    func refresh() {
        send(["pushing": [
            "sequence_id": nextSequence(),
            "command": "pushall",
            "version": 1,
            "push_target": 1
        ]])
    }

    // MARK: - Commands

    func pause() {
        command("pause")
    }

    func resume() {
        command("resume")
    }

    func stopPrint() {
        command("stop")
    }

    func setSpeed(_ level: Int) {
        let clamped = min(max(level, 1), 4)
        status.speedLevel = clamped
        let body: [String: Any] = [
            "sequence_id": nextSequence(),
            "command": "print_speed",
            "param": String(clamped)
        ]
        send(["print": body])
    }

    func setNozzleTarget(_ value: Int) {
        sendGCode("M104 S\(value)\n")
        status.nozzleTarget = Double(value)
    }

    func setBedTarget(_ value: Int) {
        sendGCode("M140 S\(value)\n")
        status.bedTarget = Double(value)
    }

    func setPartFan(_ percent: Int) {
        let clamped = min(max(percent, 0), 100)
        let raw = Int((Double(clamped) / 100.0 * 255.0).rounded())
        sendGCode("M106 P1 S\(raw)\n")
        status.coolingFan = clamped
    }

    // MARK: - Private

    private func command(_ name: String) {
        send(["print": [
            "sequence_id": nextSequence(),
            "command": name,
            "param": ""
        ]])
        lastCommandAt = Date()
        // Some firmware only sends the state change after the next push request.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refresh()
        }
    }

    private func sendGCode(_ gcode: String) {
        send(["print": [
            "sequence_id": nextSequence(),
            "command": "gcode_line",
            "param": gcode
        ]])
        lastCommandAt = Date()
    }

    private func send(_ body: [String: Any]) {
        sendHandler?(device.serial, body)
        if let data = try? JSONSerialization.data(withJSONObject: body),
           let text = String(data: data, encoding: .utf8) {
            Log.write("Command \(device.name): \(text)")
        }
    }

    private func nextSequence() -> String {
        sequence += 1
        return String(sequence)
    }
}
