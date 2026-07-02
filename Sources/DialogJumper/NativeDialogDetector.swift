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

struct NativeDialogDetector {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
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

        guard let focused else {
            return windows
        }

        return [focused] + windows.filter { CFEqual($0, focused) == false }
    }

    private func isOpenOrSaveDialog(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(kAXRoleAttribute, from: element)
        let subrole = stringAttribute(kAXSubroleAttribute, from: element)
        let title = stringAttribute(kAXTitleAttribute, from: element) ?? ""

        let dialogShape = role == "AXSheet" || subrole == "AXDialog" || subrole == "AXSystemDialog"
        let titledLikeDialog = titleMatchesNativeDialog(title)
        let hasNativeButtons = containsAnyButtonTitle(["Open", "Save", "Choose", "Cancel"], in: element, depth: 5)

        return (dialogShape || titledLikeDialog) && hasNativeButtons
    }

    private func titleMatchesNativeDialog(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else {
            return false
        }

        return ["open", "save", "choose", "export", "import"].contains { normalized.contains($0) }
    }

    private func containsAnyButtonTitle(_ titles: Set<String>, in element: AXUIElement, depth: Int) -> Bool {
        guard depth >= 0 else {
            return false
        }

        if stringAttribute(kAXRoleAttribute, from: element) == "AXButton",
           let title = stringAttribute(kAXTitleAttribute, from: element),
           titles.contains(title) {
            return true
        }

        return elementArrayAttribute(kAXChildrenAttribute, from: element).contains { child in
            containsAnyButtonTitle(titles, in: child, depth: depth - 1)
        }
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
