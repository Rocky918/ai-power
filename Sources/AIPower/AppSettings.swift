import Foundation
import ServiceManagement

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let language = "interfaceLanguage"
        static let launchAtLogin = "launchAtLogin"
        static let attemptedDefaultLoginItem = "attemptedDefaultLoginItem"
    }

    @Published var language: InterfaceLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Key.language) }
    }
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var loginItemError: String?

    init() {
        let storedLanguage = UserDefaults.standard.string(forKey: Key.language) ?? "system"
        language = InterfaceLanguage(rawValue: storedLanguage) ?? .system

        if UserDefaults.standard.object(forKey: Key.launchAtLogin) == nil {
            launchAtLogin = true
        } else {
            launchAtLogin = UserDefaults.standard.bool(forKey: Key.launchAtLogin)
        }
    }

    var locale: Locale {
        switch language {
        case .system:
            return .autoupdatingCurrent
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    var resolvedLocalizationCode: String {
        switch language {
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        case .system:
            let languages = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
                ?? Locale.preferredLanguages
            let first = languages.first?.lowercased() ?? "en"
            return first.hasPrefix("zh") ? "zh-Hans" : "en"
        }
    }

    func text(_ key: String) -> String {
        let candidates = resolvedLocalizationCode == "zh-Hans" ? ["zh-Hans", "zh-hans"] : ["en"]
        guard let resourceURL = AppResources.bundle.resourceURL,
              let bundle = candidates.lazy.compactMap({ code -> Bundle? in
                  Bundle(url: resourceURL.appendingPathComponent("\(code).lproj", isDirectory: true))
              }).first else {
            return AppResources.bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            loginItemError = nil
            UserDefaults.standard.set(enabled, forKey: Key.launchAtLogin)
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = error.localizedDescription
        }
    }

    func registerDefaultLoginItemIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Key.attemptedDefaultLoginItem) else {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            return
        }
        UserDefaults.standard.set(true, forKey: Key.attemptedDefaultLoginItem)
        guard Bundle.main.bundleURL.pathExtension == "app", launchAtLogin else { return }
        setLaunchAtLogin(true)
    }
}
