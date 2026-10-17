import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }

    var shortTitle: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "EN"
        }
    }

    static func systemDefault() -> AppLanguage {
        let code = Locale.preferredLanguages.first ?? "en"
        return code.hasPrefix("zh") ? .zhHans : .en
    }
}

/// Lightweight runtime localization. Views are re-rendered when
/// `AppModel.language` changes, so a global current language is enough.
enum Lang {
    static var current: AppLanguage = .zhHans

    static func t(_ chinese: String, _ english: String) -> String {
        current == .en ? english : chinese
    }

    static var isEnglish: Bool { current == .en }
}
