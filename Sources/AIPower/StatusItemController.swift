import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let settings: AppSettings
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel, settings: AppSettings) {
        self.model = model
        self.settings = settings
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: UsagePopoverView(
            model: model,
            settings: settings,
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        ))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.objectWillChange.merge(with: settings.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.render() }
            }.store(in: &cancellables)
        render()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            model.setPopoverIsVisible(false)
            popover.performClose(nil)
        } else {
            model.setPopoverIsVisible(true)
            model.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        model.setPopoverIsVisible(false)
    }

    private func render() {
        statusItem.isVisible = model.targetIsRunning
        guard let button = statusItem.button else { return }
        let remaining = model.snapshot?.menuWindow?.remainingPercent
        button.image = StatusIconRenderer.image(
            remaining: remaining,
            shortCycleSeverity: model.snapshot?.shortCycleSeverity
        )
        button.imagePosition = .imageLeading
        button.title = remaining.map { " \(Int($0.rounded()))%" } ?? " --%"
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.toolTip = settings.text("status.tooltip")
    }

    private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: controller)
            window.title = settings.text("settings.title")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.title = settings.text("settings.title")
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
