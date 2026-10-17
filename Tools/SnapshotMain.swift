import SwiftUI
import AppKit
import CoreGraphics
import Foundation

@main
struct SnapshotMain {
    private static var pending: [(NSWindow, String)] = []

    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { @MainActor in
                let model = AppModel.demo()
                if let service = model.selectedService {
                    let dashboard = DashboardView(service: service).environmentObject(model)
                    enqueue(dashboard, size: CGSize(width: 380, height: 624), path: "/tmp/bambubar-dashboard.png")
                }

                let loginModel = AppModel.demo()
                loginModel.authStep = .login
                enqueue(LoginView().environmentObject(loginModel), size: CGSize(width: 380, height: 486), path: "/tmp/bambubar-login.png")

                enqueue(SettingsView().environmentObject(model), size: CGSize(width: 460, height: 610), path: "/tmp/bambubar-settings.png")

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    captureAll()
                    exit(0)
                }
            }
        }
        NSApp.run()
    }

    @MainActor
    private static func enqueue<V: View>(_ view: V, size: CGSize, path: String) {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: 160, y: 160), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = true
        window.backgroundColor = .black
        window.contentView = host
        window.level = .floating
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        pending.append((window, path))
    }

    private static func captureAll() {
        for (window, path) in pending {
            let id = CGWindowID(window.windowNumber)
            if let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) {
                let rep = NSBitmapImageRep(cgImage: cg)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: path))
                    print("wrote \(path) via window \(rep.pixelsWide)x\(rep.pixelsHigh)")
                    continue
                }
            }
            // Fallback: ask the hosting view to cache itself.
            if let view = window.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: path))
                    print("wrote \(path) via cache \(rep.pixelsWide)x\(rep.pixelsHigh)")
                }
            }
        }
    }
}
