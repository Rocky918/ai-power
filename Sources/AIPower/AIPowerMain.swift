import AppKit

@main
enum AIPowerMain {
    private static var retainedDelegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private var model: AppModel?
    private var monitor: TargetApplicationMonitor?
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel(settings: settings)
        self.model = model
        statusController = StatusItemController(model: model, settings: settings)
        let monitor = TargetApplicationMonitor()
        monitor.onChange = { [weak model] running in model?.setTargetIsRunning(running) }
        self.monitor = monitor
        monitor.start()
        settings.registerDefaultLoginItemIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        model?.stop()
    }
}
