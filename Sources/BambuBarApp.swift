import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        let service = app.selectedService
        let state: PrintState = service?.status.state ?? .unknown
        let online = service?.isOnline ?? false
        let progress = state == .idle ? 0 : Double(service?.status.progress ?? 0) / 100
        let text = labelText(service: service, state: state, online: online)

        HStack(spacing: 3) {
            Image(nsImage: MenuBarIcon.image(progress: progress, state: state, online: online))
            if let text {
                Text(text)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibilityText(service: service, state: state, online: online))
    }

    private func labelText(service: PrinterService?, state: PrintState, online: Bool) -> String? {
        guard app.authStep == .ready, let service, let _ = app.session else { return nil }
        if !online || state == .offline { return Lang.t("离线", "Offline") }
        switch state {
        case .running, .prepare:
            return "\(service.status.progress)%"
        case .paused:
            return Lang.t("暂停", "Pause")
        case .finished:
            return Lang.t("完成", "Done")
        case .failed:
            return Lang.t("异常", "Error")
        case .idle, .unknown, .offline:
            return nil
        }
    }

    private func accessibilityText(service: PrinterService?, state: PrintState, online: Bool) -> String {
        guard let service else { return "BambuBar" }
        if !online { return Lang.t("\(service.device.name) 离线", "\(service.device.name) offline") }
        return "\(service.device.name) \(state.label) \(service.status.progress)%"
    }
}

@main
struct BambuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppModel()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(app)
        } label: {
            MenuBarLabel()
                .environmentObject(app)
        }
        .menuBarExtraStyle(.window)

        Window("BambuBar", id: "settings") {
            SettingsView()
                .environmentObject(app)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 700)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NotificationManager.shared.request()
        Log.write("BambuBar launched, bundle=\(Bundle.main.bundleIdentifier ?? "?")")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
