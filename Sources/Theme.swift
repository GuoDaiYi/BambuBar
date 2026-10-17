import SwiftUI
import AppKit

enum Theme {
    static let green = Color(red: 0.18, green: 0.86, blue: 0.52)
    static let mint = Color(red: 0.30, green: 0.95, blue: 0.78)
    static let cyan = Color(red: 0.30, green: 0.78, blue: 0.98)
    static let orange = Color(red: 1.00, green: 0.64, blue: 0.26)
    static let red = Color(red: 1.00, green: 0.36, blue: 0.38)
    static let purple = Color(red: 0.68, green: 0.55, blue: 1.00)

    static let backgroundTop = Color(red: 0.075, green: 0.085, blue: 0.105)
    static let backgroundBottom = Color(red: 0.045, green: 0.050, blue: 0.065)
    static let card = Color.white.opacity(0.055)
    static let cardStrong = Color.white.opacity(0.085)
    static let stroke = Color.white.opacity(0.085)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.56)
    static let textTertiary = Color.white.opacity(0.36)
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: max(a, 0.05))
    }
}

extension PrintState {
    var tint: Color {
        switch self {
        case .idle: return Theme.cyan
        case .prepare: return Theme.orange
        case .running: return Theme.green
        case .paused: return Theme.orange
        case .finished: return Theme.mint
        case .failed: return Theme.red
        case .offline: return Color.white.opacity(0.35)
        case .unknown: return Theme.purple
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .prepare: return "gearshape.2.fill"
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .finished: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else { return nil }
        if s.count == 8 {
            self.init(srgbRed: CGFloat((value >> 24) & 0xFF) / 255,
                      green: CGFloat((value >> 16) & 0xFF) / 255,
                      blue: CGFloat((value >> 8) & 0xFF) / 255,
                      alpha: max(CGFloat(value & 0xFF) / 255, 0.06))
        } else {
            self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                      green: CGFloat((value >> 8) & 0xFF) / 255,
                      blue: CGFloat(value & 0xFF) / 255,
                      alpha: 1)
        }
    }
}
