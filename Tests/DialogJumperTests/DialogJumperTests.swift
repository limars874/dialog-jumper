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

private func makeNativeDialog() -> NativeDialog {
    let application = NSRunningApplication.current
    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
    let windowElement = AXUIElementCreateApplication(application.processIdentifier)

    return NativeDialog(
        application: application,
        applicationElement: applicationElement,
        windowElement: windowElement,
        frame: .zero,
        title: "Test Dialog"
    )
}
