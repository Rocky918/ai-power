import Foundation
import AIPowerCore

enum PeriodFormatter {
    @MainActor
    static func label(for window: QuotaWindow, settings: AppSettings) -> String {
        if let name = window.limitName, !name.isEmpty, name != window.limitID {
            return name
        }
        switch QuotaPeriodKind.from(minutes: window.windowDurationMinutes) {
        case .monthly:
            return settings.text("period.monthly")
        case .weekly:
            return settings.text("period.weekly")
        case .daily:
            return settings.text("period.daily")
        case .hours(let hours):
            return settings.formatted("period.hours", hours)
        case .minutes(let minutes):
            return settings.formatted("period.minutes", minutes)
        }
    }

    @MainActor
    static func resetText(for window: QuotaWindow, settings: AppSettings) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.locale
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMdHm")
        return settings.formatted("quota.resets", formatter.string(from: window.resetsAt))
    }
}
