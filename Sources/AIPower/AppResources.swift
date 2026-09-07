import AppKit

enum AppResources {
    static let bundle: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            // Packaged apps must not fall back to SwiftPM's absolute build path.
            if let resources = Bundle.main.resourceURL,
               let bundle = Bundle(url: resources.appendingPathComponent("AIPower_AIPower.bundle")) {
                return bundle
            }
            return Bundle.main
        }
        return Bundle.module
    }()

    // Runs before app initialization, without login items, account queries or settings writes.
    static func validate() -> Bool {
        guard let logo = bundle.url(forResource: "OpenAILogo", withExtension: "svg"),
              NSImage(contentsOf: logo) != nil,
              let resources = bundle.resourceURL else { return false }
        for codes in [["en"], ["zh-Hans", "zh-hans"]] {
            guard let localized = codes.lazy.compactMap({
                Bundle(url: resources.appendingPathComponent("\($0).lproj"))
            }).first else { return false }
            let key = "codex.usage"
            guard localized.localizedString(forKey: key, value: key, table: nil) != key else { return false }
        }
        return true
    }
}
