import AppKit
import AIPowerCore

@MainActor
final class TargetApplicationMonitor {
    var onChange: ((Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.publishCurrentState() }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.publishCurrentState() }
        })
        publishCurrentState()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    private func publishCurrentState() {
        let isRunning = NSWorkspace.shared.runningApplications.contains { application in
            TargetApplication.matches(
                bundleIdentifier: application.bundleIdentifier,
                localizedName: application.localizedName
            )
        }
        onChange?(isRunning)
    }
}
