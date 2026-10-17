import Foundation

/// Per-printer state machine. It merges MQTT reports and sends pause/speed/
/// temperature commands through the shared cloud connection.
@MainActor
final class PrinterService: ObservableObject, Identifiable {
    private(set) var device: CloudDevice
    @Published private(set) var status = PrinterStatus()
    @Published private(set) var isOnline = false
    @Published private(set) var lastCommandAt: Date?
    /// Set when the firmware rejects an unsigned control command; the UI then
    /// disables controls instead of causing a loop of HMS errors.
    @Published private(set) var controlWarning: String?
    @Published private(set) var controlBlocked = false

    /// (newStatus, oldState, newState)
    var onStateTransition: ((PrinterStatus, PrintState, PrintState) -> Void)?
    var sendHandler: ((String, [String: Any]) -> Void)?

    private var sequence = 0
    private var lastLoggedPhase = ""

    var id: String { device.serial }

    init(device: CloudDevice) {
        self.device = device
        self.isOnline = device.online
    }

    /// Handles both status pushes and command acknowledgements.
    func ingest(print: [String: Any]) {
        if let result = print["result"] as? String,
           result.lowercased() == "failed" {
            let reason = (print["reason"] as? String) ?? ""
            let code = Parse.intValue(print["err_code"]) ?? 0
            Log.write("Command rejected \(device.name): code=\(code) reason=\(reason)")
            if reason.lowercased().contains("verify") || reason.contains("校验") || code == 84033543 {
                controlBlocked = true
                controlWarning = Lang.t(
                    "固件拒绝未签名命令；请使用 Handy/Studio 或 LAN Developer Mode。",
                    "Firmware rejected unsigned commands. Use Handy/Studio or LAN Developer Mode."
                )
            } else if !reason.isEmpty {
                controlWarning = Lang.t("打印机拒绝了命令：\(reason)", "The printer rejected the command: \(reason)")
            }
            return
        }

        let oldState = status.state
        let oldOnline = isOnline
        status.apply(report: print)
        if !oldOnline { isOnline = true }
        if oldState != status.state, status.state == .finished || status.state == .failed {
            onStateTransition?(status, oldState, status.state)
        }
        if !isOnline { isOnline = true }

        if status.hasFirmwareCommandError {
            controlBlocked = true
            controlWarning = Lang.t(
                "固件拒绝未签名命令（HMS 0500-0500-0001-0007）；请使用 Handy/Studio 或 LAN Developer Mode。",
                "Firmware rejected unsigned commands (HMS 0500-0500-0001-0007). Use Handy/Studio or LAN Developer Mode."
            )
        }

        if status.state == .prepare {
            let phase = status.phaseText
            if phase != lastLoggedPhase {
                lastLoggedPhase = phase
                Log.write("Phase \(device.name): prepare=\(status.preparePercent ?? -1) upload=\(status.uploadStatus ?? "-") stage=\(status.mcPrintStage ?? -1) -> \(phase)")
            }
        } else {
            lastLoggedPhase = ""
        }
    }

    func clearControlBlock() {
        controlBlocked = false
        controlWarning = nil
        refresh()
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
        guard ensureControlAllowed() else { return }
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
        guard ensureControlAllowed() else { return }
        sendGCode("M104 S\(value)\n")
        status.nozzleTarget = Double(value)
    }

    func setBedTarget(_ value: Int) {
        guard ensureControlAllowed() else { return }
        sendGCode("M140 S\(value)\n")
        status.bedTarget = Double(value)
    }

    func setPartFan(_ percent: Int) {
        guard ensureControlAllowed() else { return }
        let clamped = min(max(percent, 0), 100)
        let raw = Int((Double(clamped) / 100.0 * 255.0).rounded())
        sendGCode("M106 P1 S\(raw)\n")
        status.coolingFan = clamped
    }

    // MARK: - Private

    private func command(_ name: String) {
        guard ensureControlAllowed() else { return }
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
        guard ensureControlAllowed() else { return }
        send(["print": [
            "sequence_id": nextSequence(),
            "command": "gcode_line",
            "param": gcode
        ]])
        lastCommandAt = Date()
    }

    private func ensureControlAllowed() -> Bool {
        if controlBlocked {
            controlWarning = Lang.t(
                "固件拒绝未签名命令；请使用 Handy/Studio 或 LAN Developer Mode。",
                "Firmware rejected unsigned commands. Use Handy/Studio or LAN Developer Mode."
            )
            return false
        }
        return true
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
