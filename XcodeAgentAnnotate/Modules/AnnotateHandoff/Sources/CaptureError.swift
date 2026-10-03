import Foundation

public enum CaptureError: LocalizedError, Equatable, Sendable {
    case invalidSelection
    case multipleSelections
    case noXcode
    case accessibilityRequired
    case unverifiedEditor(String)
    case noLocalFile
    case invalidRequest
    case handoffFailed
    case payloadTooLarge
    case clipboardWriteFailed

    public var errorDescription: String? {
        switch self {
        case .invalidSelection: "Xcode supplied an unsupported source selection. The clipboard was not changed."
        case .multipleSelections: "Use a single selection or caret. Multiple selections are not supported yet."
        case .noXcode: "Invoke this command from the active Xcode source editor."
        case .accessibilityRequired: "Grant Annotate for Agent Accessibility access in System Settings, then invoke the Xcode command again."
        case let .unverifiedEditor(reason): "Could not verify a single active source editor (\(reason)). Close split editors, comparison views, and the debug console, then focus the source editor and try again. The clipboard was not changed."
        case .noLocalFile: "Could not resolve a saved local source file. Save the file, focus its editor, and try again."
        case .invalidRequest: "The capture request is invalid or expired. Invoke the Xcode command again."
        case .handoffFailed: "Could not open Annotate for Agent. Install and open the containing app first."
        case .payloadTooLarge: "The capture exceeds the prototype’s 16 MB handoff limit. Select a smaller section."
        case .clipboardWriteFailed: "macOS could not write the annotation to the clipboard. Try copying again."
        }
    }
}
