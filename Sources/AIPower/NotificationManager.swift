import Foundation
import UserNotifications
import AIPowerCore

@MainActor
final class NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    func requestAuthorizationIfNeeded() {
        guard !defaults.bool(forKey: "notificationPermissionRequested") else { return }
        defaults.set(true, forKey: "notificationPermissionRequested")
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(snapshot: RateLimitSnapshot, settings: AppSettings) {
        for window in snapshot.windows where window.severity == .critical {
            let cycle = Int64(window.resetsAt.timeIntervalSince1970)
            let marker = "notification.\(window.limitID).\(window.role).\(cycle)"
            guard !defaults.bool(forKey: marker) else { continue }
            defaults.set(true, forKey: marker)

            let content = UNMutableNotificationContent()
            content.title = settings.text("notification.title")
            let period = PeriodFormatter.label(for: window, settings: settings)
            content.body = settings.formatted(
                "notification.body",
                period,
                Int(window.remainingPercent.rounded())
            )
            content.sound = .default
            center.add(UNNotificationRequest(
                identifier: marker,
                content: content,
                trigger: nil
            ))
        }
    }
}
