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

        let languageID = CommandLine.arguments.dropFirst().first ?? "zh"
        let language: AppLanguage = languageID == "en" ? .en : .zhHans
        Lang.current = language

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { @MainActor in
                let dir = URL(fileURLWithPath: "/tmp/bambubar-shots/\(languageID)", isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let model = AppModel.demo(language: language)
                if let service = model.selectedService {
                    let dashboard = DashboardView(service: service).environmentObject(model)
                    enqueue(dashboard, size: CGSize(width: 620, height: 470),
                            path: dir.appendingPathComponent("dashboard.png").path)
                }

                let loginModel = AppModel.demo(language: language)
                loginModel.authStep = .login
                enqueue(LoginView().environmentObject(loginModel), size: CGSize(width: 600, height: 400),
                        path: dir.appendingPathComponent("login.png").path)

                enqueue(SettingsView().environmentObject(model), size: CGSize(width: 680, height: 450),
                        path: dir.appendingPathComponent("settings.png").path)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
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
