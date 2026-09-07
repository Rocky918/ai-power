import AppKit

@main
enum AIPowerMain {
    private static var retainedDelegate: AppDelegate?

    static func main() {
        if CommandLine.arguments.contains("--check-resources") {
            let valid = AppResources.validate()
            print(valid ? "AI Power resources OK: logo, English, Simplified Chinese" : "AI Power resources FAILED")
            exit(valid ? 0 : 1)
        }
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
