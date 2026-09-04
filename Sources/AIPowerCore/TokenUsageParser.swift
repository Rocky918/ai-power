import Foundation

public enum TokenUsageParserError: LocalizedError, Equatable {
    case missingResult
    case invalidBuckets
    case invalidBucket(String)

    public var errorDescription: String? {
        switch self {
        case .missingResult:
            return "The app-server token response did not contain a result."
        case .invalidBuckets:
            return "The app-server token response contained invalid daily buckets."
        case .invalidBucket(let identifier):
            return "The token usage bucket \(identifier) was incomplete."
        }
    }
}

public enum TokenUsageParser {
    public static func parseResponse(
        _ object: [String: Any],
        receivedAt: Date = Date()
    ) throws -> TokenUsageSnapshot {
        guard let result = object["result"] as? [String: Any] else {
            throw TokenUsageParserError.missingResult
        }
        return try parseResult(result, receivedAt: receivedAt)
    }

    public static func parseResult(
        _ result: [String: Any],
        receivedAt: Date = Date()
    ) throws -> TokenUsageSnapshot {
        guard let rawBuckets = result["dailyUsageBuckets"] else {
            return TokenUsageSnapshot(dailyBuckets: [], receivedAt: receivedAt)
        }
        if rawBuckets is NSNull {
            return TokenUsageSnapshot(dailyBuckets: [], receivedAt: receivedAt)
        }
        guard let buckets = rawBuckets as? [[String: Any]] else {
            throw TokenUsageParserError.invalidBuckets
        }

        var parsed: [DailyTokenUsageBucket] = []
        for (index, bucket) in buckets.enumerated() {
            guard
                let startDate = bucket["startDate"] as? String,
                !startDate.isEmpty,
                let tokens = integer(bucket["tokens"])
            else {
                throw TokenUsageParserError.invalidBucket("#\(index + 1)")
            }
            parsed.append(DailyTokenUsageBucket(startDate: startDate, tokens: tokens))
        }

        let unique = Dictionary(grouping: parsed, by: \.startDate).compactMap { $0.value.last }
        return TokenUsageSnapshot(dailyBuckets: unique, receivedAt: receivedAt)
    }

    private static func integer(_ value: Any?) -> Int64? {
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) }
        return nil
    }
}
