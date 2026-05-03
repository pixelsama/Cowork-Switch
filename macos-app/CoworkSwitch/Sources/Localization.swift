import Foundation

enum AppLanguage {
    case english
    case chinese

    static var current: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? "en"

        if preferredLanguage.hasPrefix("zh") {
            return .chinese
        }

        if preferredLanguage.hasPrefix("en") {
            return .english
        }

        return .english
    }

    var localizationCode: String {
        switch self {
        case .english:
            return "en"
        case .chinese:
            return "zh-Hans"
        }
    }
}

enum L10n {
    static func tr(_ key: String) -> String {
        let bundle = localizedBundle()
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)

        if value != key {
            return value
        }

        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.current, arguments: arguments)
    }

    private static func localizedBundle() -> Bundle {
        let localizationCode = AppLanguage.current.localizationCode

        if let path = Bundle.main.path(forResource: localizationCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return Bundle.main
    }
}
