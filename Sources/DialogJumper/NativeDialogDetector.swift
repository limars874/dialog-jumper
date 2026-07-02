import AppKit
import ApplicationServices

struct NativeDialog {
    let application: NSRunningApplication
    let applicationElement: AXUIElement
    let windowElement: AXUIElement
    let frame: CGRect
    let title: String

    var processIdentifier: pid_t {
        application.processIdentifier
    }
}

struct NativeDialogElementSnapshot {
    let role: String?
    let subrole: String?
    let title: String?
    let children: [NativeDialogElementSnapshot]

    init(
        role: String? = nil,
        subrole: String? = nil,
        title: String? = nil,
        children: [NativeDialogElementSnapshot] = []
    ) {
        self.role = role
        self.subrole = subrole
        self.title = title
        self.children = children
    }
}

struct NativeDialogClassifier {
    private let nativeButtonTitles: Set<String> = ["Open", "Save", "Choose", "Cancel"]
    private let nativeTitleFragments = ["open", "save", "choose", "export", "import"]

    func isOpenOrSaveDialog(_ element: NativeDialogElementSnapshot) -> Bool {
        let title = element.title ?? ""
        let dialogShape = element.role == "AXSheet"
            || element.subrole == "AXDialog"
            || element.subrole == "AXSystemDialog"
        let titledLikeDialog = titleMatchesNativeDialog(title)
        let hasNativeButtons = containsAnyButtonTitle(nativeButtonTitles, in: element, depth: 5)

        return (dialogShape || titledLikeDialog) && hasNativeButtons
    }

    private func titleMatchesNativeDialog(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else {
            return false
        }

        return nativeTitleFragments.contains { normalized.contains($0) }
    }

    private func containsAnyButtonTitle(
        _ titles: Set<String>,
        in element: NativeDialogElementSnapshot,
        depth: Int
    ) -> Bool {
        guard depth >= 0 else {
            return false
        }

        if element.role == "AXButton",
           let title = element.title,
           titles.contains(title) {
            return true
        }

        return element.children.contains { child in
            containsAnyButtonTitle(titles, in: child, depth: depth - 1)
        }
    }
}

enum NativeDialogWindowOrdering {
    static func focusedFirst<Element>(
        focused: Element?,
        windows: [Element],
        equal: (Element, Element) -> Bool
    ) -> [Element] {
        guard let focused else {
            return windows
        }

        return [focused] + windows.filter { equal($0, focused) == false }
    }
}

struct NativeDialogDetector {
    private let workspace: NSWorkspace
    private let classifier: NativeDialogClassifier

    init(
        workspace: NSWorkspace = .shared,
        classifier: NativeDialogClassifier = NativeDialogClassifier()
    ) {
        self.workspace = workspace
        self.classifier = classifier
    }

    func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func detectFrontmostDialog() -> NativeDialog? {
        guard hasAccessibilityPermission(prompt: false),
              let application = workspace.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        let windows = focusedWindowFirst(from: applicationElement)

        for window in windows where isOpenOrSaveDialog(window) {
            guard let frame = frame(of: window) else {
                continue
            }

            return NativeDialog(
                application: application,
                applicationElement: applicationElement,
                windowElement: window,
                frame: frame,
                title: stringAttribute(kAXTitleAttribute, from: window) ?? application.localizedName ?? AppMetadata.name
            )
        }

        return nil
    }

    private func focusedWindowFirst(from applicationElement: AXUIElement) -> [AXUIElement] {
        let focused = elementAttribute(kAXFocusedWindowAttribute, from: applicationElement)
        let windows = elementArrayAttribute(kAXWindowsAttribute, from: applicationElement)

        return NativeDialogWindowOrdering.focusedFirst(focused: focused, windows: windows) { lhs, rhs in
            CFEqual(lhs, rhs)
        }
    }

    private func isOpenOrSaveDialog(_ element: AXUIElement) -> Bool {
        classifier.isOpenOrSaveDialog(snapshot(of: element, depth: 5))
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = valueAttribute(kAXPositionAttribute, from: element),
              let sizeValue = valueAttribute(kAXSizeAttribute, from: element) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func snapshot(of element: AXUIElement, depth: Int) -> NativeDialogElementSnapshot {
        let children: [NativeDialogElementSnapshot]
        if depth > 0 {
            children = elementArrayAttribute(kAXChildrenAttribute, from: element).map { child in
                snapshot(of: child, depth: depth - 1)
            }
        } else {
            children = []
        }

        return NativeDialogElementSnapshot(
            role: stringAttribute(kAXRoleAttribute, from: element),
            subrole: stringAttribute(kAXSubroleAttribute, from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            children: children
        )
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func valueAttribute(_ attribute: String, from element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return (value as! AXValue)
    }

    private func elementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func elementArrayAttribute(_ attribute: String, from element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return []
        }

        return value as? [AXUIElement] ?? []
    }
}
