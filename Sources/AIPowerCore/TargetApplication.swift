import Foundation

public enum TargetApplication {
    public static let bundleIdentifiers: Set<String> = [
        "com.openai.codex",
        "com.openai.chatgpt",
        "com.openai.chat"
    ]

    public static let names: Set<String> = [
        "codex",
        "chatgpt"
    ]

    public static func matches(bundleIdentifier: String?, localizedName: String?) -> Bool {
        if let bundleIdentifier, bundleIdentifiers.contains(bundleIdentifier.lowercased()) {
            return true
        }
        if let localizedName, names.contains(localizedName.lowercased()) {
            return true
        }
        return false
    }
}
