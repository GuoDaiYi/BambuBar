import Foundation

/// Read-only per-printer state store.
///
/// BambuBar is a progress monitor: it merges MQTT status pushes but deliberately
/// has no pause/resume/cancel/speed/temperature command path.
@MainActor
final class PrinterService: ObservableObject, Identifiable {
    private(set) var device: CloudDevice
    @Published private(set) var status = PrinterStatus()
    @Published private(set) var isOnline = false

    /// Called when a print finishes or fails, used for notifications.
    var onStateTransition: ((PrinterStatus, PrintState, PrintState) -> Void)?
    /// Sends a read-only `pushall` request through the cloud connection.
    var sendHandler: ((String, [String: Any]) -> Void)?

    private var sequence = 0
    private var lastLoggedPhase = ""

    var id: String { device.serial }

    init(device: CloudDevice) {
        self.device = device
        self.isOnline = device.online
    }

    /// Handles a status push. Command/result payloads are ignored because the
    /// monitor never sends printer commands.
    func ingest(print: [String: Any]) {
        if print["result"] != nil { return }

        let oldState = status.state
        status.apply(report: print)
        if !isOnline { isOnline = true }

        if oldState != status.state,
           status.state == .finished || status.state == .failed {
            onStateTransition?(status, oldState, status.state)
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
            isOnline = device.online
            return
        }
        if now.timeIntervalSince(last) > 150 {
            isOnline = false
        }
    }

    /// Requests a full status snapshot. This is a read operation, not a control.
    func refresh() {
        sequence += 1
        sendHandler?(device.serial, [
            "pushing": [
                "sequence_id": String(sequence),
                "command": "pushall",
                "version": 1,
                "push_target": 1
            ]
        ])
    }
}
