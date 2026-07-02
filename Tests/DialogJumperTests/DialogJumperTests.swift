import Testing
import Foundation
import AppKit
@testable import DialogJumper

@Test func bootstrapPackageHasExecutable() {
    #expect(AppMetadata.name == "dialog-jumper")
}

@Test func resolverAcceptsDirectoryString() throws {
    let directory = try makeFixtureDirectory()
    let resolved = ClipboardFolderResolver().resolve(rawString: directory.path)

    #expect(resolved == directory.standardizedFileURL)
}

@Test func resolverUsesFileParent() throws {
    let directory = try makeFixtureDirectory()
    let file = directory.appendingPathComponent("note.txt")
    try "fixture".write(to: file, atomically: true, encoding: .utf8)

    let resolved = ClipboardFolderResolver().resolve(rawString: file.path)

    #expect(resolved == directory.standardizedFileURL)
}

@Test func resolverAcceptsFileURLDirectory() throws {
    let directory = try makeFixtureDirectory()
    let resolved = ClipboardFolderResolver().resolve(rawString: directory.absoluteString)

    #expect(resolved == directory.standardizedFileURL)
}

@Test func resolverRejectsMissingPath() {
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent("dialog-jumper-tests")
        .appendingPathComponent(UUID().uuidString)

    #expect(ClipboardFolderResolver().resolve(rawString: missing.path) == nil)
}

@Test func resolverRejectsBlankAndPlainText() {
    let resolver = ClipboardFolderResolver()

    #expect(resolver.resolve(rawString: "  \n\t ") == nil)
    #expect(resolver.resolve(rawString: "copied words") == nil)
}

@Test func resolverExpandsHomeDirectory() {
    let resolved = ClipboardFolderResolver().resolve(rawString: "~")
    let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    #expect(resolved == home)
}

@MainActor
@Test func coordinatorReportsMissingClipboardFolder() {
    let pasteboard = makePasteboard()
    defer { release(pasteboard) }
    pasteboard.setString("copied words", forType: .string)
    let coordinator = DialogJumpCoordinator(pasteboard: pasteboard, transport: .testing())
    var statuses: [DialogJumpCoordinator.JumpStatus] = []
    coordinator.onStatusChange = { statuses.append($0) }

    coordinator.jumpToClipboardFolder(in: nil)

    #expect(coordinator.status == .waitingForClipboardFolder)
    #expect(statuses == [.waitingForClipboardFolder])
    #expect(coordinator.status.displayText == "Copy a folder path first")
}

@MainActor
@Test func coordinatorReportsMissingDialogAfterResolvingFolder() throws {
    let pasteboard = makePasteboard()
    defer { release(pasteboard) }
    let directory = try makeFixtureDirectory()
    pasteboard.setString(directory.path, forType: .string)
    let coordinator = DialogJumpCoordinator(pasteboard: pasteboard, transport: .testing())
    var statuses: [DialogJumpCoordinator.JumpStatus] = []
    coordinator.onStatusChange = { statuses.append($0) }

    coordinator.jumpToClipboardFolder(in: nil)

    #expect(coordinator.status == .waitingForDialog)
    #expect(statuses == [.waitingForDialog])
    #expect(coordinator.status.displayText == "Open or Save dialog required")
}

@MainActor
@Test func coordinatorWritesFolderSendsKeysRestoresClipboardAndReportsSent() throws {
    let pasteboard = makePasteboard()
    defer { release(pasteboard) }
    let directory = try makeFixtureDirectory()
    let originalClipboardString = directory.absoluteString
    pasteboard.setString(originalClipboardString, forType: .string)
    var postedKeys: [PostedKey] = []
    var activatedPID: pid_t?
    var pasteAction: (@MainActor () -> Void)?
    var restoreAction: (@MainActor () -> Void)?
    let transport = DialogJumpTransport.testing(
        activate: { activatedPID = $0.processIdentifier },
        postKey: { keyCode, flags, pid in
            postedKeys.append(PostedKey(keyCode: keyCode, flags: flags, pid: pid))
        },
        schedulePasteAndRestore: { paste, restore in
            pasteAction = paste
            restoreAction = restore
        }
    )
    let coordinator = DialogJumpCoordinator(pasteboard: pasteboard, transport: transport)
    var statuses: [DialogJumpCoordinator.JumpStatus] = []
    coordinator.onStatusChange = { statuses.append($0) }
    let dialog = makeNativeDialog()

    coordinator.jumpToClipboardFolder(in: dialog)

    let folderURL = directory.standardizedFileURL
    #expect(activatedPID == dialog.processIdentifier)
    #expect(pasteboard.string(forType: .string) == folderURL.path)
    #expect(statuses == [.sending(folderURL)])
    #expect(postedKeys == [
        PostedKey(keyCode: 5, flags: [.maskCommand, .maskShift], pid: dialog.processIdentifier)
    ])

    pasteAction?()

    #expect(postedKeys == [
        PostedKey(keyCode: 5, flags: [.maskCommand, .maskShift], pid: dialog.processIdentifier),
        PostedKey(keyCode: 9, flags: .maskCommand, pid: dialog.processIdentifier),
        PostedKey(keyCode: 36, flags: [], pid: dialog.processIdentifier)
    ])

    restoreAction?()

    #expect(pasteboard.string(forType: .string) == originalClipboardString)
    #expect(coordinator.status == .sent(folderURL))
    #expect(coordinator.status.displayText == "Sent \(folderURL.lastPathComponent)")
    #expect(statuses == [.sending(folderURL), .sent(folderURL)])
}

@MainActor
@Test func coordinatorKeepsChangedClipboardAndReportsFailure() throws {
    let pasteboard = makePasteboard()
    defer { release(pasteboard) }
    let directory = try makeFixtureDirectory()
    pasteboard.setString(directory.absoluteString, forType: .string)
    var restoreAction: (@MainActor () -> Void)?
    let transport = DialogJumpTransport.testing(
        schedulePasteAndRestore: { _, restore in
            restoreAction = restore
        }
    )
    let coordinator = DialogJumpCoordinator(pasteboard: pasteboard, transport: transport)

    coordinator.jumpToClipboardFolder(in: makeNativeDialog())
    pasteboard.clearContents()
    pasteboard.setString("user-change", forType: .string)
    restoreAction?()

    #expect(pasteboard.string(forType: .string) == "user-change")
    #expect(coordinator.status == .failed("Clipboard changed; kept current content"))
    #expect(coordinator.status.displayText == "Clipboard changed; kept current content")
}

@MainActor
@Test func coordinatorRestoresClipboardWhenCommandGSendFails() throws {
    let pasteboard = makePasteboard()
    defer { release(pasteboard) }
    let directory = try makeFixtureDirectory()
    let originalClipboardString = directory.absoluteString
    pasteboard.setString(originalClipboardString, forType: .string)
    let transport = DialogJumpTransport.testing(
        postKey: { _, _, _ in throw TestTransportError.failed }
    )
    let coordinator = DialogJumpCoordinator(pasteboard: pasteboard, transport: transport)

    coordinator.jumpToClipboardFolder(in: makeNativeDialog())

    #expect(pasteboard.string(forType: .string) == originalClipboardString)
    #expect(coordinator.status == .failed("Jump failed"))
}

@Test func classifierAcceptsDialogShapeWithNativeButton() {
    let classifier = NativeDialogClassifier()
    let dialog = NativeDialogElementSnapshot(
        role: "AXSheet",
        title: "Export",
        children: [
            NativeDialogElementSnapshot(role: "AXGroup", children: [
                NativeDialogElementSnapshot(role: "AXButton", title: "Open")
            ])
        ]
    )

    #expect(classifier.isOpenOrSaveDialog(dialog))
}

@Test func classifierAcceptsNativeTitleWithChooseButton() {
    let classifier = NativeDialogClassifier()
    let dialog = NativeDialogElementSnapshot(
        role: "AXWindow",
        title: "Choose Folder",
        children: [
            NativeDialogElementSnapshot(role: "AXButton", title: "Choose")
        ]
    )

    #expect(classifier.isOpenOrSaveDialog(dialog))
}

@Test func classifierRejectsOrdinaryWindowWithUnrelatedControls() {
    let classifier = NativeDialogClassifier()
    let ordinaryWindow = NativeDialogElementSnapshot(
        role: "AXWindow",
        title: "Preferences",
        children: [
            NativeDialogElementSnapshot(role: "AXButton", title: "Apply")
        ]
    )

    #expect(classifier.isOpenOrSaveDialog(ordinaryWindow) == false)
}

@Test func windowOrderingPlacesFocusedWindowFirst() {
    let ordered = NativeDialogWindowOrdering.focusedFirst(focused: 2, windows: [1, 2, 3]) { lhs, rhs in
        lhs == rhs
    }

    #expect(ordered == [2, 1, 3])
}

@MainActor
@Test func companionPanelShowsDialogStatusAndPosition() throws {
    _ = NSApplication.shared
    let coordinator = DialogJumpCoordinator(transport: .testing())
    let panelController = CompanionPanelController(coordinator: coordinator)
    defer { panelController.hidePanel() }
    let dialogFrame = CGRect(x: 24, y: 48, width: 320, height: 180)

    panelController.show(dialog: makeNativeDialog(frame: dialogFrame))

    let window = try #require(panelController.window)
    let button = try #require(firstSubview(of: NSButton.self, in: window.contentView))
    let statusLabel = try #require(panelStatusLabel(in: window.contentView))
    let expectedOrigin = NSPoint(
        x: dialogFrame.maxX + 12,
        y: dialogFrame.maxY - window.frame.height
    )

    #expect(window.isVisible)
    #expect(button.isEnabled)
    #expect(statusLabel.stringValue == "Ready")
    #expect(window.frame.origin == expectedOrigin)
}

@MainActor
@Test func companionPanelShowsPermissionRequiredStateAndHides() throws {
    _ = NSApplication.shared
    let panelController = CompanionPanelController(coordinator: DialogJumpCoordinator(transport: .testing()))

    panelController.showPermissionRequired()

    let window = try #require(panelController.window)
    let button = try #require(firstSubview(of: NSButton.self, in: window.contentView))
    let statusLabel = try #require(panelStatusLabel(in: window.contentView))
    #expect(window.isVisible)
    #expect(button.isEnabled == false)
    #expect(statusLabel.stringValue == "Enable Accessibility")

    panelController.hidePanel()

    #expect(window.isVisible == false)
}

@MainActor
@Test func companionPanelButtonDispatchesCurrentDialogToCoordinator() throws {
    _ = NSApplication.shared
    let pasteboard = makePasteboard()
    defer { release(pasteboard) }
    let directory = try makeFixtureDirectory()
    pasteboard.setString(directory.path, forType: .string)
    var postedKeys: [PostedKey] = []
    let coordinator = DialogJumpCoordinator(
        pasteboard: pasteboard,
        transport: .testing(
            postKey: { keyCode, flags, pid in
                postedKeys.append(PostedKey(keyCode: keyCode, flags: flags, pid: pid))
            }
        )
    )
    let panelController = CompanionPanelController(coordinator: coordinator)
    defer { panelController.hidePanel() }
    let dialog = makeNativeDialog()
    panelController.show(dialog: dialog)
    let button = try #require(firstSubview(of: NSButton.self, in: panelController.window?.contentView))

    button.performClick(nil)

    let folderURL = directory.standardizedFileURL
    #expect(coordinator.status == .sending(folderURL))
    #expect(pasteboard.string(forType: .string) == folderURL.path)
    #expect(postedKeys == [
        PostedKey(keyCode: 5, flags: [.maskCommand, .maskShift], pid: dialog.processIdentifier)
    ])
}

@MainActor
@Test func applicationControllerShowsPermissionRequiredWhenAccessibilityDenied() {
    _ = NSApplication.shared
    let detector = TestDialogDetector(permissionGranted: false)
    let panel = TestPanelPresenter()
    let timer = TestRefreshTimer()
    var scheduledFire: (@MainActor () -> Void)?
    let controller = DialogJumperApplicationController(
        detector: detector,
        panelController: panel,
        makeRefreshTimer: { fire in
            scheduledFire = fire
            return timer
        }
    )

    controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(detector.permissionPrompts == [true])
    #expect(panel.permissionRequiredCount == 1)
    #expect(panel.hiddenCount == 0)
    #expect(panel.shownDialogs.isEmpty)
    #expect(scheduledFire == nil)
}

@MainActor
@Test func applicationControllerHidesPanelWhenPermissionGrantedWithoutDialog() {
    _ = NSApplication.shared
    let detector = TestDialogDetector(permissionGranted: true)
    let panel = TestPanelPresenter()
    let timer = TestRefreshTimer()
    var scheduledFire: (@MainActor () -> Void)?
    let controller = DialogJumperApplicationController(
        detector: detector,
        panelController: panel,
        makeRefreshTimer: { fire in
            scheduledFire = fire
            return timer
        }
    )

    controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(detector.permissionPrompts == [true])
    #expect(detector.detectCallCount == 1)
    #expect(panel.hiddenCount == 1)
    #expect(panel.shownDialogs.isEmpty)
    #expect(scheduledFire != nil)

    controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

    #expect(timer.invalidateCount == 1)
}

@MainActor
@Test func applicationControllerShowsDetectedDialogAndRefreshCallbackUpdatesPanel() {
    _ = NSApplication.shared
    let firstDialog = makeNativeDialog(frame: CGRect(x: 10, y: 20, width: 30, height: 40))
    let secondDialog = makeNativeDialog(frame: CGRect(x: 50, y: 60, width: 70, height: 80))
    let detector = TestDialogDetector(permissionGranted: true, detectedDialog: firstDialog)
    let panel = TestPanelPresenter()
    var scheduledFire: (@MainActor () -> Void)?
    let controller = DialogJumperApplicationController(
        detector: detector,
        panelController: panel,
        makeRefreshTimer: { fire in
            scheduledFire = fire
            return TestRefreshTimer()
        }
    )

    controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    detector.detectedDialog = secondDialog
    scheduledFire?()

    #expect(detector.detectCallCount == 2)
    #expect(panel.shownDialogs.map(\.frame) == [firstDialog.frame, secondDialog.frame])
    #expect(panel.hiddenCount == 0)
}

private func makeFixtureDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("dialog-jumper-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .standardizedFileURL

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private struct PostedKey: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let pid: pid_t
}

private enum TestTransportError: Error {
    case failed
}

@MainActor
private extension DialogJumpTransport {
    static func testing(
        activate: @escaping Activate = { _ in },
        postKey: @escaping PostKey = { _, _, _ in },
        schedulePasteAndRestore: @escaping SchedulePasteAndRestore = { _, _ in }
    ) -> DialogJumpTransport {
        DialogJumpTransport(
            activate: activate,
            postKey: postKey,
            schedulePasteAndRestore: schedulePasteAndRestore
        )
    }
}

private func makePasteboard() -> NSPasteboard {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("dialog-jumper-tests-\(UUID().uuidString)"))
    pasteboard.clearContents()
    return pasteboard
}

private func release(_ pasteboard: NSPasteboard) {
    pasteboard.clearContents()
    pasteboard.releaseGlobally()
}

private func makeNativeDialog(frame: CGRect = .zero) -> NativeDialog {
    let application = NSRunningApplication.current
    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
    let windowElement = AXUIElementCreateApplication(application.processIdentifier)

    return NativeDialog(
        application: application,
        applicationElement: applicationElement,
        windowElement: windowElement,
        frame: frame,
        title: "Test Dialog"
    )
}

@MainActor
private func firstSubview<T: NSView>(of type: T.Type, in view: NSView?) -> T? {
    guard let view else {
        return nil
    }

    if let typed = view as? T {
        return typed
    }

    for subview in view.subviews {
        if let match = firstSubview(of: type, in: subview) {
            return match
        }
    }

    return nil
}

@MainActor
private func panelStatusLabel(in view: NSView?) -> NSTextField? {
    allSubviews(of: NSTextField.self, in: view).first { textField in
        textField.stringValue != "Clipboard Folder"
    }
}

@MainActor
private func allSubviews<T: NSView>(of type: T.Type, in view: NSView?) -> [T] {
    guard let view else {
        return []
    }

    let current = (view as? T).map { [$0] } ?? []
    return current + view.subviews.flatMap { subview in
        allSubviews(of: type, in: subview)
    }
}

private final class TestDialogDetector: NativeDialogDetecting {
    var permissionGranted: Bool
    var detectedDialog: NativeDialog?
    var permissionPrompts: [Bool] = []
    var detectCallCount = 0

    init(permissionGranted: Bool, detectedDialog: NativeDialog? = nil) {
        self.permissionGranted = permissionGranted
        self.detectedDialog = detectedDialog
    }

    func hasAccessibilityPermission(prompt: Bool) -> Bool {
        permissionPrompts.append(prompt)
        return permissionGranted
    }

    func detectFrontmostDialog() -> NativeDialog? {
        detectCallCount += 1
        return detectedDialog
    }
}

@MainActor
private final class TestPanelPresenter: CompanionPanelPresenting {
    var shownDialogs: [NativeDialog] = []
    var shownStatuses: [String] = []
    var permissionRequiredCount = 0
    var hiddenCount = 0

    func show(dialog: NativeDialog) {
        shownDialogs.append(dialog)
    }

    func show(status: String) {
        shownStatuses.append(status)
    }

    func showPermissionRequired() {
        permissionRequiredCount += 1
    }

    func hidePanel() {
        hiddenCount += 1
    }
}

private final class TestRefreshTimer: RefreshTimerInvalidating {
    var invalidateCount = 0

    func invalidate() {
        invalidateCount += 1
    }
}
