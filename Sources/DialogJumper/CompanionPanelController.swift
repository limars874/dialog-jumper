import AppKit

@MainActor
final class CompanionPanelController: NSWindowController {
    private let coordinator: DialogJumpCoordinator
    private let actionButton = NSButton(title: "Clipboard Folder", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private var currentDialog: NativeDialog?

    init(coordinator: DialogJumpCoordinator) {
        self.coordinator = coordinator

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 72),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = AppMetadata.name
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        super.init(window: panel)

        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func show(dialog: NativeDialog) {
        currentDialog = dialog
        actionButton.isEnabled = true
        show(status: coordinator.status.displayText)
        positionPanel(near: dialog.frame)
    }

    func show(status: String) {
        statusLabel.stringValue = status
        window?.orderFrontRegardless()
    }

    func showPermissionRequired() {
        currentDialog = nil
        actionButton.isEnabled = false
        show(status: "Enable Accessibility")
        window?.center()
    }

    func hidePanel() {
        currentDialog = nil
        window?.orderOut(nil)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let stack = NSStackView(views: [actionButton, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        actionButton.target = self
        actionButton.action = #selector(jumpToClipboardFolder)
        actionButton.bezelStyle = .rounded
        actionButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.maximumNumberOfLines = 1
        statusLabel.textColor = .secondaryLabelColor

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 190)
        ])
    }

    private func positionPanel(near frame: CGRect) {
        guard let window else {
            return
        }

        let panelSize = window.frame.size
        let x = frame.maxX + 12
        let y = frame.maxY - panelSize.height
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func jumpToClipboardFolder() {
        coordinator.jumpToClipboardFolder(in: currentDialog)
    }
}
