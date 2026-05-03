import Foundation

enum L10n {
    static func tr(_ key: String, localeIdentifier: String) -> String {
        let languageCode = localeIdentifier.split(separator: "_").first.map(String.init) ?? "en"

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }

        return NSLocalizedString(key, comment: "")
    }
}
