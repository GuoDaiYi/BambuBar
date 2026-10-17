import SwiftUI
import AppKit
import CoreText

/// MIT-licensed Tabler Icons (https://tabler.io/icons), bundled as a font.
/// Keeping the codepoints in one place makes icon swaps and fallbacks simple.
enum TBIcon: String {
    case printer = "\u{eb0e}"
    case settings = "\u{eb20}"
    case language = "\u{ebbe}"
    case arrowsExchange = "\u{f1f4}"
    case pause = "\u{ed45}"
    case play = "\u{ed46}"
    case stop = "\u{ed4a}"
    case refresh = "\u{eb13}"
    case flame = "\u{ec2c}"
    case bed = "\u{eb5c}"
    case wind = "\u{ec34}"
    case gauge = "\u{eab1}"
    case stack = "\u{eb2d}"
    case clock = "\u{ea70}"
    case download = "\u{ea96}"
    case package = "\u{eaff}"
    case alertTriangle = "\u{ea06}"
    case bell = "\u{ea35}"
    case power = "\u{eb0d}"
    case close = "\u{eb55}"
    case externalLink = "\u{ea99}"
    case chevronDown = "\u{ea5f}"
    case mail = "\u{eae5}"
    case lock = "\u{eae2}"
    case user = "\u{eb4d}"
    case check = "\u{ea5e}"
    case circleCheck = "\u{ea67}"
    case arrowRight = "\u{ea1f}"
    case cloud = "\u{ea76}"
    case wifi = "\u{eb52}"
    case world = "\u{eb54}"
    case bolt = "\u{ea38}"
    case shieldLock = "\u{ed58}"
    case infoCircle = "\u{eac5}"
    case thermometer = "\u{ef67}"
    case volumeOff = "\u{f1c3}"
    case equal = "\u{ee87}"
    case rocket = "\u{ec45}"
}

struct TBIconView: View {
    let icon: TBIcon
    var size: CGFloat = 14
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(icon.rawValue)
            .font(.custom("tabler-icons", size: size))
            .foregroundStyle(color)
            .frame(width: size * 1.25, height: size * 1.25)
            .accessibilityHidden(true)
    }
}

enum AppFonts {
    private static var registered = false

    /// Registers the bundled Tabler icon font. The snapshot tool runs outside
    /// the app bundle, so it also tries the repository-relative asset path.
    static func register() {
        guard !registered else { return }
        registered = true
        var candidates: [URL] = []
        if let bundled = Bundle.main.url(forResource: "tabler-icons", withExtension: "ttf") {
            candidates.append(bundled)
        }
        let local = URL(fileURLWithPath: "Assets/ThirdPartyIcons/tabler-icons.ttf")
        if FileManager.default.fileExists(atPath: local.path) {
            candidates.append(local)
        }
        for url in candidates {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
