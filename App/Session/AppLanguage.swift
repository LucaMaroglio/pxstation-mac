import AppKit
import Foundation

/// Interface language. The choice is stored as `AppleLanguages` in the app's own defaults
/// domain, which macOS reads at launch (the same mechanism as System Settings › General ›
/// Language & Region › Applications), so a change applies after a relaunch.
///
/// With no choice the app follows the system's preferred languages; when none of them is
/// supported, Bundle falls back to the development region (English).
@MainActor
enum AppLanguage {
    private static let key = "AppleLanguages"

    /// Languages the app ships (one `.lproj` per String Catalog language), English first.
    static var supported: [String] {
        let codes = Bundle.main.localizations.filter { $0 != "Base" }
        return codes.sorted { lhs, rhs in
            if lhs == "en" { return rhs != "en" }
            if rhs == "en" { return false }
            return displayName(lhs) < displayName(rhs)
        }
    }

    /// The user's explicit choice, or nil to follow the system.
    static var selected: String? {
        get {
            guard let id = Bundle.main.bundleIdentifier,
                  let languages = UserDefaults.standard.persistentDomain(forName: id)?[key] as? [String]
            else { return nil }
            return languages.first
        }
        set {
            if let newValue {
                UserDefaults.standard.set([newValue], forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// The choice in effect when the app was launched ("" = system default).
    static let selectedAtLaunch: String = selected ?? ""

    /// The supported language the system preferences resolve to (English if none matches).
    static var systemLanguage: String {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[key] as? [String]
        let preferences = global ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: supported, forPreferences: preferences).first ?? "en"
    }

    /// A language's name in that language ("English", "Italiano").
    static func displayName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code
    }

    /// Starts a new instance of the app and quits this one.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}
