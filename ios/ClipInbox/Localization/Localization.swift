import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "한국어"
    case english = "English"
    case japanese = "日本語"

    var id: String { rawValue }

    var sharedValue: SharedAppLanguage {
        switch self {
        case .korean: return .ko
        case .english: return .en
        case .japanese: return .ja
        }
    }

    var localeIdentifier: String { sharedValue.rawValue }

    init(storedValue: String) {
        switch storedValue {
        case Self.english.rawValue, "en": self = .english
        case Self.japanese.rawValue, "ja": self = .japanese
        default: self = .korean
        }
    }
}

enum L10n {
    static var language: AppLanguage {
        AppLanguage(storedValue: SharedClipQueue.loadConfiguration().language.rawValue)
    }

    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        guard let path = Bundle.main.path(forResource: selected.localeIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func text(_ key: String, locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        let language: AppLanguage
        switch code {
        case "en": language = .english
        case "ja": language = .japanese
        default: language = .korean
        }
        return text(key, language: language)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: language.localeIdentifier), arguments: arguments)
    }
}

extension Preferences {
    var appLanguage: AppLanguage { AppLanguage(storedValue: language) }
    var sharedSaveMode: SharedSaveMode { SharedSaveMode(rawValue: shareMode) ?? .quick }
}
