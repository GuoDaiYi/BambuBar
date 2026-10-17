import SwiftUI
import AppKit
import Combine

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

/// Rounds the actual hosting window, not only the SwiftUI cards.
struct WindowCornerRadius: NSViewRepresentable {
    var radius: CGFloat = 18

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window, let content = window.contentView else { return }
        content.wantsLayer = true
        content.layer?.cornerRadius = radius
        content.layer?.masksToBounds = true
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}

/// Shared dark glass background used by every window.
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
        .background(WindowCornerRadius(radius: 18))
    }
}

// MARK: - Cards

struct CardSurface: ViewModifier {
    var padding: CGFloat = 14
    var radius: CGFloat = 18
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
    func card(padding: CGFloat = 14, radius: CGFloat = 18, strong: Bool = false) -> some View {
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
    let icon: TBIcon
    let text: String
    var tint: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            TBIconView(icon: icon, size: 9, color: tint)
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
    var icon: TBIcon? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                TBIconView(icon: icon, size: 10, color: Theme.textSecondary)
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

    private var items: [(Int, String, TBIcon)] {
        [
            (1, Lang.t("静音", "Silent"), .volumeOff),
            (2, Lang.t("标准", "Standard"), .equal),
            (3, Lang.t("运动", "Sport"), .rocket),
            (4, Lang.t("狂暴", "Ludicrous"), .bolt)
        ]
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.0) { item in
                let selected = level == item.0
                Button {
                    onSelect(item.0)
                } label: {
                    VStack(spacing: 3) {
                        TBIconView(icon: item.2, size: 13, color: selected ? Theme.green : Theme.textSecondary)
                        Text(item.1)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
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
    let icon: TBIcon
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
                    TBIconView(icon: icon, size: 11, color: tint)
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
                Text(enabled ? (targetText ?? Lang.t("目标 \(Int(target.rounded()))°", "Target \(Int(target.rounded()))°")) : "—")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Buttons

struct RoundIconButton: View {
    let icon: TBIcon
    var tint: Color = Theme.textSecondary
    var size: CGFloat = 30
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            TBIconView(icon: icon, size: 13, color: tint)
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
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.045, green: 0.105, blue: 0.082),
                            Color(red: 0.020, green: 0.040, blue: 0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                        .stroke(Theme.green.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Theme.green.opacity(0.18), radius: 10, y: 4)
            TBIconView(icon: .printer, size: size * 0.42, color: Theme.green)
                .shadow(color: Theme.green.opacity(0.35), radius: 6)
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

        // Template images are rendered by macOS in the menu bar's own color:
        // white on a dark menu bar, black on a light one.
        let ink = NSColor.black
        let center = NSPoint(x: 9, y: 9)
        let radius: CGFloat = 7.0

        ink.withAlphaComponent(0.28).setStroke()
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = 1.3
        track.stroke()

        let clamped = online ? max(0.0, min(progress, 1.0)) : 0
        if clamped > 0.001 {
            ink.setStroke()
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: -90, endAngle: -90 + 360 * clamped, clockwise: false)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            arc.stroke()
        }

        if let symbol = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 7.5, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
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
        image.isTemplate = true
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


// MARK: - Language toggle

/// Two large segmented targets; the whole tile is clickable, not just the text.
/// Two large segmented language targets. The whole tile is a hit target.
struct LanguageToggle: View {
    @EnvironmentObject private var app: AppModel
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppLanguage.allCases) { language in
                let selected = app.language == language
                Button {
                    app.setLanguage(language)
                } label: {
                    Text(language.shortTitle)
                        .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? Theme.green : Theme.textTertiary)
                        .frame(width: compact ? 36 : 110, height: compact ? 28 : 30)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? Theme.green.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - Popover animation

struct PopoverEntrance: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.97, anchor: .top)
            .offset(y: visible ? 0 : -6)
            .onAppear {
                visible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        visible = true
                    }
                }
            }
            .onDisappear { visible = false }
    }
}
