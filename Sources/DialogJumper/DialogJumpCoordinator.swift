import AppKit
import CoreGraphics

@MainActor
final class DialogJumpCoordinator {
    enum JumpStatus: Equatable {
        case idle
        case waitingForClipboardFolder
        case waitingForDialog
        case sending(URL)
        case sent(URL)
        case failed(String)

        var displayText: String {
            switch self {
            case .idle:
                "Ready"
            case .waitingForClipboardFolder:
                "Copy a folder path first"
            case .waitingForDialog:
                "Open or Save dialog required"
            case .sending(let url):
                "Jumping to \(url.lastPathComponent)"
            case .sent(let url):
                "Sent \(url.lastPathComponent)"
            case .failed(let message):
                message
            }
        }
    }

    private enum KeyCode {
        static let g: CGKeyCode = 5
        static let v: CGKeyCode = 9
        static let `return`: CGKeyCode = 36
    }

    private let pasteboard: NSPasteboard
    private let resolver: ClipboardFolderResolver
    private let transport: DialogJumpTransport
    private(set) var status: JumpStatus = .idle {
        didSet {
            onStatusChange?(status)
        }
    }

    var onStatusChange: ((JumpStatus) -> Void)?

    init(
        pasteboard: NSPasteboard = .general,
        resolver: ClipboardFolderResolver = ClipboardFolderResolver(),
        transport: DialogJumpTransport = .live
    ) {
        self.pasteboard = pasteboard
        self.resolver = resolver
        self.transport = transport
    }

    func jumpToClipboardFolder(in dialog: NativeDialog?) {
        guard let folderURL = resolver.resolve(rawString: pasteboard.string(forType: .string)) else {
            status = .waitingForClipboardFolder
            return
        }

        guard let dialog else {
            status = .waitingForDialog
            return
        }

        do {
            try startJump(to: folderURL, in: dialog)
        } catch {
            status = .failed("Jump failed")
        }
    }

    private func startJump(to folderURL: URL, in dialog: NativeDialog) throws {
        status = .sending(folderURL)

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(folderURL.path, forType: .string) else {
            snapshot.restore(to: pasteboard)
            throw JumpTransportError.pasteboardWriteFailed
        }

        let jumpChangeCount = pasteboard.changeCount
        do {
            transport.activate(dialog.application)
            try sendCommandShiftG(to: dialog.processIdentifier)
        } catch {
            snapshot.restore(to: pasteboard)
            throw error
        }

        transport.schedulePasteAndRestore(
            { [weak self] in
                guard let self else {
                    return
                }

                try? self.sendPasteAndReturn(to: dialog.processIdentifier)
            },
            { [weak self] in
                self?.restorePasteboardIfUntouched(
                    snapshot,
                    expectedChangeCount: jumpChangeCount,
                    folderURL: folderURL
                )
            }
        )
    }

    private func restorePasteboardIfUntouched(
        _ snapshot: PasteboardSnapshot,
        expectedChangeCount: Int,
        folderURL: URL
    ) {
        guard pasteboard.changeCount == expectedChangeCount else {
            status = .failed("Clipboard changed; kept current content")
            return
        }

        snapshot.restore(to: pasteboard)
        status = .sent(folderURL)
    }

    private func sendCommandShiftG(to pid: pid_t) throws {
        try transport.postKey(KeyCode.g, [.maskCommand, .maskShift], pid)
    }

    private func sendPasteAndReturn(to pid: pid_t) throws {
        try transport.postKey(KeyCode.v, .maskCommand, pid)
        try transport.postKey(KeyCode.return, [], pid)
    }
}

struct DialogJumpTransport {
    typealias Activate = @MainActor (NSRunningApplication) -> Void
    typealias PostKey = @MainActor (CGKeyCode, CGEventFlags, pid_t) throws -> Void
    typealias SchedulePasteAndRestore = @MainActor (
        @escaping @MainActor () -> Void,
        @escaping @MainActor () -> Void
    ) -> Void

    let activate: Activate
    let postKey: PostKey
    let schedulePasteAndRestore: SchedulePasteAndRestore

    static let live = DialogJumpTransport(
        activate: { application in
            if #available(macOS 14.0, *) {
                application.activate()
            } else {
                application.activate(options: [.activateIgnoringOtherApps])
            }
        },
        postKey: { keyCode, flags, pid in
            guard let source = CGEventSource(stateID: .hidSystemState),
                  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
                throw JumpTransportError.keyboardEventCreationFailed
            }

            keyDown.flags = flags
            keyUp.flags = flags
            keyDown.postToPid(pid)
            keyUp.postToPid(pid)
        },
        schedulePasteAndRestore: { paste, restore in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                paste()
                try? await Task.sleep(for: .milliseconds(1_500))
                restore()
            }
        }
    )
}

private enum JumpTransportError: Error {
    case pasteboardWriteFailed
    case keyboardEventCreationFailed
}

private struct PasteboardSnapshot {
    let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                }
            }
            return copy
        } ?? []

        return PasteboardSnapshot(items: copiedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard items.isEmpty == false else {
            return
        }

        pasteboard.writeObjects(items)
    }
}
