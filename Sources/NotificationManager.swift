import Foundation
import AppKit
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private var requested = false

    func request() {
        guard !requested else { return }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.write("Notification permission error: \(error.localizedDescription)")
            } else {
                Log.write("Notification permission granted: \(granted)")
            }
        }
    }

    func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let icon = monochromePrinterImage(),
           let attachment = try? UNNotificationAttachment(
                identifier: "bambubar-printer",
                url: icon,
                options: nil
           ) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.write("Notification failed: \(error.localizedDescription)")
            }
        }
    }

    /// A single monochrome printer glyph for notification thumbnails.
    private func monochromePrinterImage() -> URL? {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BambuBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let url = cache.appendingPathComponent("notification-printer.png")
        if FileManager.default.fileExists(atPath: url.path) { return url }

        let size: CGFloat = 160
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let ink = NSColor(white: 0.72, alpha: 1)
        if let symbol = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 104, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
            if let glyph = symbol.withSymbolConfiguration(config) {
                let rect = NSRect(
                    x: (size - glyph.size.width) / 2,
                    y: (size - glyph.size.height) / 2,
                    width: glyph.size.width,
                    height: glyph.size.height
                )
                glyph.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        do {
            try png.write(to: url)
            return url
        } catch {
            Log.write("Notification icon write failed: \(error.localizedDescription)")
            return nil
        }
    }
}
