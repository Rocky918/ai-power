import Foundation

public enum RateLimitParserError: LocalizedError, Equatable {
    case missingResult
    case missingRateLimits
    case invalidWindow(String)

    public var errorDescription: String? {
        switch self {
        case .missingResult:
            return "The app-server response did not contain a result."
        case .missingRateLimits:
            return "No Codex rate-limit windows were returned."
        case .invalidWindow(let identifier):
            return "The rate-limit window \(identifier) was incomplete."
        }
    }
}

public enum RateLimitParser {
    public static func parseResponse(
        _ object: [String: Any],
        receivedAt: Date = Date()
    ) throws -> RateLimitSnapshot {
        guard let result = object["result"] as? [String: Any] else {
            throw RateLimitParserError.missingResult
        }
        return try parseResult(result, receivedAt: receivedAt)
    }

    public static func parseResult(
        _ result: [String: Any],
        receivedAt: Date = Date()
    ) throws -> RateLimitSnapshot {
        var buckets: [(String, [String: Any])] = []

        if let byID = result["rateLimitsByLimitId"] as? [String: Any] {
            for key in byID.keys.sorted() {
                if let bucket = byID[key] as? [String: Any] {
                    buckets.append((key, bucket))
                }
            }
        }

        if buckets.isEmpty, let legacy = result["rateLimits"] as? [String: Any] {
            let identifier = string(legacy["limitId"]) ?? "codex"
            buckets.append((identifier, legacy))
        }

        guard !buckets.isEmpty else {
            throw RateLimitParserError.missingRateLimits
        }

        var windows: [QuotaWindow] = []
        var discoveredPlan: String?
        var creditBalance: String?
        let resetCredits = parseResetCredits(result["rateLimitResetCredits"])

        for (fallbackID, bucket) in buckets {
            let limitID = string(bucket["limitId"]) ?? fallbackID
            let limitName = string(bucket["limitName"])
            let planType = string(bucket["planType"])
            discoveredPlan = discoveredPlan ?? planType

            if let credits = bucket["credits"] as? [String: Any] {
                creditBalance = creditBalance ?? string(credits["balance"])
            }

            for role in ["primary", "secondary"] {
                guard let rawWindow = bucket[role] as? [String: Any] else { continue }
                guard
                    let usedPercent = number(rawWindow["usedPercent"]),
                    let duration = integer(rawWindow["windowDurationMins"]),
                    let resetTimestamp = number(rawWindow["resetsAt"])
                else {
                    throw RateLimitParserError.invalidWindow("\(limitID).\(role)")
                }

                let id = "\(limitID):\(role):\(duration):\(Int64(resetTimestamp))"
                windows.append(
                    QuotaWindow(
                        id: id,
                        limitID: limitID,
                        limitName: limitName,
                        role: role,
                        usedPercent: usedPercent,
                        windowDurationMinutes: duration,
                        resetsAt: Date(timeIntervalSince1970: resetTimestamp),
                        planType: planType
                    )
                )
            }
        }

        guard !windows.isEmpty else {
            throw RateLimitParserError.missingRateLimits
        }

        let unique = Dictionary(grouping: windows, by: \.id).compactMap { $0.value.first }
        return RateLimitSnapshot(
            windows: unique,
            planType: discoveredPlan,
            creditBalance: creditBalance,
            resetCredits: resetCredits,
            receivedAt: receivedAt
        )
    }

    private static func parseResetCredits(_ value: Any?) -> RateLimitResetCredits? {
        guard
            let object = value as? [String: Any],
            let availableCount = integer(object["availableCount"])
        else {
            return nil
        }

        let expirationDates = (object["credits"] as? [[String: Any]] ?? []).compactMap { credit -> Date? in
            guard let timestamp = number(credit["expiresAt"]), timestamp.isFinite else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        }
        return RateLimitResetCredits(
            availableCount: availableCount,
            earliestExpiration: expirationDates.min()
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = number(value), number.isFinite else { return nil }
        return Int(number)
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
}
