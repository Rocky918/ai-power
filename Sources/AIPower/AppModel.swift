import Foundation
import AIPowerCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var tokenUsage: TokenUsageSnapshot?
    @Published private(set) var targetIsRunning = false
    @Published private(set) var popoverIsVisible = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var tokenUsageError: String?

    let settings: AppSettings
    private let client = CodexAppServerClient()
    private let notifications = NotificationManager()
    private var timer: Timer?
    private var refreshQueued = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func setTargetIsRunning(_ running: Bool) {
        guard running != targetIsRunning else { return }
        targetIsRunning = running
        if running {
            notifications.requestAuthorizationIfNeeded()
            startTimer()
            refresh()
        } else {
            timer?.invalidate()
            timer = nil
            isRefreshing = false
            refreshQueued = false
            client.stop()
        }
    }

    func refresh() {
        guard targetIsRunning else { return }
        if isRefreshing {
            refreshQueued = true
            return
        }
        isRefreshing = true
        client.fetchRateLimits { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                switch result {
                case .success(let accountUsage):
                    self.snapshot = accountUsage.rateLimits
                    self.lastError = nil
                    if let tokenUsage = accountUsage.tokenUsage {
                        self.tokenUsage = tokenUsage
                    }
                    self.tokenUsageError = accountUsage.tokenUsageError
                    self.notifications.evaluate(snapshot: accountUsage.rateLimits, settings: self.settings)
                case .failure(let error):
                    if self.targetIsRunning {
                        self.lastError = error.localizedDescription
                    }
                }
                if self.refreshQueued {
                    self.refreshQueued = false
                    self.refresh()
                }
            }
        }
    }

    func setPopoverIsVisible(_ visible: Bool) {
        popoverIsVisible = visible
    }

    func stop() {
        timer?.invalidate()
        client.stop()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
}
