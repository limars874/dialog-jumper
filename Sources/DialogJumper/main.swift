import AppKit

struct AppMetadata {
    static let name = "dialog-jumper"
}

@MainActor
final class DialogJumperApplicationController: NSObject, NSApplicationDelegate {
    private let detector = NativeDialogDetector()
    private let coordinator: DialogJumpCoordinator
    private let panelController: CompanionPanelController
    private var refreshTimer: Timer?

    override init() {
        coordinator = DialogJumpCoordinator()
        panelController = CompanionPanelController(coordinator: coordinator)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.onStatusChange = { [weak panelController] status in
            panelController?.show(status: status.displayText)
        }

        if detector.hasAccessibilityPermission(prompt: true) {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshDialogState()
                }
            }
            refreshDialogState()
        } else {
            panelController.showPermissionRequired()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func refreshDialogState() {
        guard let dialog = detector.detectFrontmostDialog() else {
            panelController.hidePanel()
            return
        }

        panelController.show(dialog: dialog)
    }
}

let app = NSApplication.shared
let controller = DialogJumperApplicationController()
app.delegate = controller
app.run()
