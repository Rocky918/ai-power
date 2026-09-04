import Foundation
import AIPowerCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var targetIsRunning = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

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
                case .success(let snapshot):
                    self.snapshot = snapshot
                    self.lastError = nil
                    self.notifications.evaluate(snapshot: snapshot, settings: self.settings)
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
