import Foundation
import AIPowerCore

enum SelfTestFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): return message }
    }
}

var assertions = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    assertions += 1
    if !condition() { throw SelfTestFailure.failed(message) }
}

do {
    let result: [String: Any] = [
        "rateLimitsByLimitId": [
            "codex": [
                "limitId": "codex", "planType": "plus",
                "primary": ["usedPercent": 62, "windowDurationMins": 300, "resetsAt": 1_800_000_000],
                "secondary": ["usedPercent": 8, "windowDurationMins": 10_080, "resetsAt": 1_800_500_000]
            ]
        ]
    ]
    let snapshot = try RateLimitParser.parseResult(result)
    try expect(snapshot.windows.count == 2, "dynamic windows were not parsed")
    try expect(snapshot.planType == "plus", "plan type was not parsed")
    try expect(snapshot.menuWindow?.windowDurationMinutes == 10_080, "longest window was not selected")
    try expect(snapshot.menuWindow?.remainingPercent == 92, "remaining percent is incorrect")
    try expect(QuotaSeverity.forRemainingPercent(20) == .normal, "20% should be normal")
    try expect(QuotaSeverity.forRemainingPercent(19.99) == .warning, "below 20% should warn")
    try expect(QuotaSeverity.forRemainingPercent(10) == .warning, "10% should warn")
    try expect(QuotaSeverity.forRemainingPercent(9.99) == .critical, "below 10% should be critical")
    try expect(QuotaPeriodKind.from(minutes: 300) == .hours(5), "5-hour period misclassified")
    try expect(QuotaPeriodKind.from(minutes: 10_080) == .weekly, "weekly period misclassified")
    try expect(QuotaPeriodKind.from(minutes: 43_200) == .monthly, "monthly period misclassified")
    try expect(TargetApplication.matches(bundleIdentifier: "com.openai.codex", localizedName: "ChatGPT"), "Codex app not recognized")
    try expect(!TargetApplication.matches(bundleIdentifier: "com.apple.Safari", localizedName: "Safari"), "unrelated app recognized")
    do {
        _ = try RateLimitParser.parseResult([:])
        throw SelfTestFailure.failed("missing windows did not fail")
    } catch RateLimitParserError.missingRateLimits {
        assertions += 1
    }
    print("AI Power core self-test passed (\(assertions) assertions).")
} catch {
    fputs("AI Power core self-test failed: \(error)\n", stderr)
    exit(1)
}
