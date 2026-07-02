import AppKit

struct AppMetadata {
    static let name = "dialog-jumper"
}

protocol NativeDialogDetecting {
    func hasAccessibilityPermission(prompt: Bool) -> Bool
    func detectFrontmostDialog() -> NativeDialog?
}

extension NativeDialogDetector: NativeDialogDetecting {}

@MainActor
protocol CompanionPanelPresenting: AnyObject {
    func show(dialog: NativeDialog)
    func show(status: String)
    func showPermissionRequired()
    func hidePanel()
}

extension CompanionPanelController: CompanionPanelPresenting {}

protocol RefreshTimerInvalidating: AnyObject {
    func invalidate()
}

extension Timer: RefreshTimerInvalidating {}

typealias RefreshTimerFactory = @MainActor (_ fire: @escaping @MainActor () -> Void) -> any RefreshTimerInvalidating

@MainActor
final class DialogJumperApplicationController: NSObject, NSApplicationDelegate {
    private let detector: any NativeDialogDetecting
    private let coordinator: DialogJumpCoordinator
    private let panelController: any CompanionPanelPresenting
    private let makeRefreshTimer: RefreshTimerFactory
    private var refreshTimer: (any RefreshTimerInvalidating)?

    init(
        detector: any NativeDialogDetecting = NativeDialogDetector(),
        coordinator: DialogJumpCoordinator = DialogJumpCoordinator(),
        panelController: (any CompanionPanelPresenting)? = nil,
        makeRefreshTimer: @escaping RefreshTimerFactory = DialogJumperApplicationController.makeLiveRefreshTimer
    ) {
        self.detector = detector
        self.coordinator = coordinator
        self.panelController = panelController ?? CompanionPanelController(coordinator: coordinator)
        self.makeRefreshTimer = makeRefreshTimer
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.onStatusChange = { [weak panelController] status in
            panelController?.show(status: status.displayText)
        }

        if detector.hasAccessibilityPermission(prompt: true) {
            refreshTimer = makeRefreshTimer { [weak self] in
                self?.refreshDialogState()
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

    private static func makeLiveRefreshTimer(
        fire: @escaping @MainActor () -> Void
    ) -> any RefreshTimerInvalidating {
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            Task { @MainActor in
                fire()
            }
        }
    }
}

let app = NSApplication.shared
let controller = DialogJumperApplicationController()
app.delegate = controller
app.run()
