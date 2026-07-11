import Foundation

enum SharedL10n {
    static func text(_ key: String, language: SharedAppLanguage? = nil) -> String {
        let selected = language ?? SharedClipQueue.loadConfiguration().language
        guard let path = Bundle.main.path(forResource: selected.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func format(_ key: String, language: SharedAppLanguage? = nil, _ arguments: CVarArg...) -> String {
        let selected = language ?? SharedClipQueue.loadConfiguration().language
        return String(format: text(key, language: selected),
                      locale: Locale(identifier: selected.rawValue),
                      arguments: arguments)
    }
}
