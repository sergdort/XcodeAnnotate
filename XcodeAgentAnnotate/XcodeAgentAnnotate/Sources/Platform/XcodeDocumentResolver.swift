import AnnotateHandoff
import AppKit
import ApplicationServices

enum XcodeDocumentResolver {
    static func resolve(_ request: CaptureRequest) throws -> URL {
        guard AXIsProcessTrusted() else { throw CaptureError.accessibilityRequired }
        guard let app = NSRunningApplication(processIdentifier: request.xcodeProcessID),
              app.bundleIdentifier?.hasPrefix("com.apple.dt.Xcode") == true
        else {
            throw CaptureError.noXcode
        }
        let application = AXUIElementCreateApplication(request.xcodeProcessID)
        guard let focused = element(application, kAXFocusedUIElementAttribute),
              let window = element(application, kAXFocusedWindowAttribute)
        else {
            throw CaptureError.unverifiedEditor("no focused element or window in Xcode")
        }

        // Reject focus changes and unsupported editors instead of pairing code with a guessed path.
        var current: AXUIElement? = focused
        var verifiedEditor: AXUIElement?
        for _ in 0 ..< 12 {
            guard let candidate = current else { break }
            if let value = attribute(candidate, kAXValueAttribute) as? String,
               CaptureRequest.digest(value) == request.bufferDigest
            {
                verifiedEditor = candidate
                break
            }
            current = element(candidate, kAXParentAttribute)
        }
        guard let editor = verifiedEditor else {
            let role = attribute(focused, kAXRoleAttribute) as? String ?? "unknown"
            throw CaptureError.unverifiedEditor("focused \(role) does not contain the captured buffer")
        }
        guard let editorWindow = element(editor, kAXWindowAttribute), CFEqual(editorWindow, window) else {
            throw CaptureError.unverifiedEditor("editor belongs to a different window")
        }

        // Prefer the document nearest the editor; fall back to the window's document like Copilot for Xcode.
        // In split editors the window document can name the other pane's file.
        current = editor
        for _ in 0 ..< 12 {
            guard let candidate = current else { break }
            if let document = localDocument(candidate) { return document }
            if CFEqual(candidate, window) { break }
            current = element(candidate, kAXParentAttribute)
        }
        guard let document = localDocument(window) else { throw CaptureError.noLocalFile }
        return document
    }

    private static func localDocument(_ element: AXUIElement) -> URL? {
        guard let raw = attribute(element, kAXDocumentAttribute) as? String,
              let url = URL(string: raw), url.isFileURL,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
        return url.standardizedFileURL
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
}
