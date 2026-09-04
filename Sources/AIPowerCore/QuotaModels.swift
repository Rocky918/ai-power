import Foundation

public enum QuotaSeverity: Int, Comparable, Sendable {
    case normal = 0
    case warning = 1
    case critical = 2

    public static func < (lhs: QuotaSeverity, rhs: QuotaSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func forRemainingPercent(_ value: Double) -> QuotaSeverity {
        if value < 10 { return .critical }
        if value < 20 { return .warning }
        return .normal
    }
}

public struct QuotaWindow: Identifiable, Equatable, Sendable {
    public let id: String
    public let limitID: String
    public let limitName: String?
    public let role: String
    public let usedPercent: Double
    public let windowDurationMinutes: Int
    public let resetsAt: Date
    public let planType: String?

    public init(
        id: String,
        limitID: String,
        limitName: String?,
        role: String,
        usedPercent: Double,
        windowDurationMinutes: Int,
        resetsAt: Date,
        planType: String?
    ) {
        self.id = id
        self.limitID = limitID
        self.limitName = limitName
        self.role = role
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.windowDurationMinutes = max(windowDurationMinutes, 1)
        self.resetsAt = resetsAt
        self.planType = planType
    }

    public var remainingPercent: Double {
        min(max(100 - usedPercent, 0), 100)
    }

    public var severity: QuotaSeverity {
        QuotaSeverity.forRemainingPercent(remainingPercent)
    }
}

public struct RateLimitSnapshot: Equatable, Sendable {
    public let windows: [QuotaWindow]
    public let planType: String?
    public let creditBalance: String?
    public let receivedAt: Date

    public init(
        windows: [QuotaWindow],
        planType: String?,
        creditBalance: String?,
        receivedAt: Date = Date()
    ) {
        self.windows = windows.sorted {
            if $0.windowDurationMinutes == $1.windowDurationMinutes {
                return $0.id < $1.id
            }
            return $0.windowDurationMinutes < $1.windowDurationMinutes
        }
        self.planType = planType
        self.creditBalance = creditBalance
        self.receivedAt = receivedAt
    }

    public var menuWindow: QuotaWindow? {
        windows.max { lhs, rhs in
            if lhs.windowDurationMinutes == rhs.windowDurationMinutes {
                if lhs.limitID == "codex" { return false }
                if rhs.limitID == "codex" { return true }
                return lhs.id < rhs.id
            }
            return lhs.windowDurationMinutes < rhs.windowDurationMinutes
        }
    }

    public var shortCycleSeverity: QuotaSeverity? {
        guard let menuWindow else { return nil }
        let shorter = windows.filter { $0.id != menuWindow.id }
        guard !shorter.isEmpty else { return nil }
        return shorter.map(\.severity).max()
    }
}

public enum QuotaPeriodKind: Equatable, Sendable {
    case minutes(Int)
    case hours(Int)
    case daily
    case weekly
    case monthly

    public static func from(minutes: Int) -> QuotaPeriodKind {
        if minutes >= 40_000 { return .monthly }
        if minutes >= 9_000 { return .weekly }
        if minutes >= 1_200 { return .daily }
        if minutes % 60 == 0 { return .hours(minutes / 60) }
        return .minutes(minutes)
    }
}
