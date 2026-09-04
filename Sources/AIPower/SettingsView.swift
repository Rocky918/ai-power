import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Toggle(settings.text("launch.at.login"), isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            Picker(settings.text("language"), selection: $settings.language) {
                Text(settings.text("language.system")).tag(InterfaceLanguage.system)
                Text(settings.text("language.zh")).tag(InterfaceLanguage.simplifiedChinese)
                Text(settings.text("language.en")).tag(InterfaceLanguage.english)
            }
            if let error = settings.loginItemError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Divider()
            Text(settings.text("privacy.note")).font(.caption).foregroundStyle(.secondary)
            Text(settings.text("unofficial.note")).font(.caption2).foregroundStyle(.tertiary)
        }
        .formStyle(.grouped)
        .padding(6)
        .frame(width: 420, height: 250)
        .environment(\.locale, settings.locale)
    }
}
