import SwiftUI
import AppKit

// MARK: - Background

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}

struct PanelBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView()
            LinearGradient(
                colors: [Theme.backgroundTop.opacity(0.97), Theme.backgroundBottom.opacity(0.985)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.green.opacity(0.10), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 260
            )
            RadialGradient(
                colors: [Theme.cyan.opacity(0.06), Color.clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 220
            )
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Cards

struct CardSurface: ViewModifier {
    var padding: CGFloat = 14
    var radius: CGFloat = 16
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(strong ? Theme.cardStrong : Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func card(padding: CGFloat = 14, radius: CGFloat = 16, strong: Bool = false) -> some View {
        modifier(CardSurface(padding: padding, radius: radius, strong: strong))
    }
}

// MARK: - Progress

struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 8
    var size: CGFloat = 86

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.004, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.65), tint, tint.opacity(0.85)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: 5)
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Badges

struct StateBadge: View {
    let state: PrintState
    let online: Bool
    var compact: Bool = false

    private var effective: PrintState { online ? state : .offline }
    private var tint: Color { effective.tint }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint.opacity(0.9), radius: 3)
            Text(compact ? effective.shortLabel : effective.label)
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(tint.opacity(0.13)))
        .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    var tint: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.055)))
        .overlay(Capsule().stroke(Color.white.opacity(0.055), lineWidth: 1))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Speed

struct SpeedSelector: View {
    let level: Int
    let enabled: Bool
    let onSelect: (Int) -> Void

    private let items: [(Int, String, String)] = [
        (1, "静音", "tortoise.fill"),
        (2, "标准", "equal"),
        (3, "运动", "hare.fill"),
        (4, "狂暴", "bolt.fill")
    ]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.0) { item in
                let selected = level == item.0
                Button {
                    onSelect(item.0)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.2)
                            .font(.system(size: 12, weight: .semibold))
                        Text(item.1)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(selected ? Theme.green : Theme.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected ? Theme.green.opacity(0.16) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selected ? Theme.green.opacity(0.28) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.45)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

// MARK: - Temperature tile

struct TempTile: View {
    let icon: String
    let title: String
    let current: Double
    let target: Double
    let tint: Color
    var unit: String = "°C"
    var enabled: Bool = true
    var targetText: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Text(title)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(current.rounded()))")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(unit)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(enabled ? (targetText ?? "目标 \(Int(target.rounded()))°") : "—")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Spool

struct SpoolView: View {
    let tray: AMSTray

    private var color: Color {
        Color(hex: tray.colorHex) ?? Color(white: 0.6)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.95), color.opacity(0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                Circle()
                    .fill(Theme.backgroundTop.opacity(0.92))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                if tray.isActive {
                    Circle()
                        .stroke(Theme.green, lineWidth: 2)
                        .frame(width: 41, height: 41)
                        .shadow(color: Theme.green.opacity(0.5), radius: 4)
                }
            }
            .frame(width: 42, height: 42)

            Text(tray.isEmpty ? "空" : tray.displayType)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(tray.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                .lineLimit(1)
            Text(tray.remainText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(tray.isActive ? Theme.green : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tray.isActive ? Theme.green.opacity(0.07) : Color.clear)
        )
    }
}

// MARK: - Buttons

struct RoundIconButton: View {
    let icon: String
    var tint: Color = Theme.textSecondary
    var size: CGFloat = 30
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct LogoMark: View {
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.green, Theme.mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.green.opacity(0.35), radius: 10, y: 4)
            Image(systemName: "printer.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color(red: 0.03, green: 0.12, blue: 0.08))
            Circle()
                .fill(Theme.orange)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.30, y: -size * 0.30)
                .shadow(color: Theme.orange.opacity(0.5), radius: 3)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Menu bar icon

enum MenuBarIcon {
    static func image(progress: Double, state: PrintState, online: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let tint: NSColor = online ? NSColor(state.tint) : NSColor.white.withAlphaComponent(0.38)
        let center = NSPoint(x: 9, y: 9)
        let radius: CGFloat = 7.0

        NSColor.white.withAlphaComponent(0.22).setStroke()
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = 1.3
        track.stroke()

        let clamped = max(0.0, min(progress, 1.0))
        if clamped > 0.001 {
            tint.setStroke()
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: -90, endAngle: -90 + 360 * clamped, clockwise: false)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            arc.stroke()
        }

        if let symbol = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 7.5, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [tint]))
            let configured = symbol.withSymbolConfiguration(config) ?? symbol
            let symbolSize = configured.size
            let rect = NSRect(
                x: center.x - symbolSize.width / 2,
                y: center.y - symbolSize.height / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            configured.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        image.isTemplate = false
        return image
    }
}

// MARK: - Text helpers

struct LabeledValue: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
    }
}
