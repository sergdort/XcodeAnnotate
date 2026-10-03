import AppKit
import XcodeKit

final class CopyCodeCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation,
                 completionHandler: @escaping (Error?) -> Void)
    {
        do {
            guard invocation.buffer.selections.count == 1 else { throw CaptureError.multipleSelections }
            guard let range = invocation.buffer.selections.firstObject as? XCSourceTextRange,
                  let lines = invocation.buffer.lines as? [String] else { throw CaptureError.invalidSelection }
            let capture = try CodeCapture.capture(
                lines: lines,
                start: .init(line: range.start.line, column: range.start.column),
                end: .init(line: range.end.line, column: range.end.column)
            )
            let digest = CaptureRequest.digest(invocation.buffer.completeBuffer)
            DispatchQueue.main.async {
                do {
                    guard let xcode = NSWorkspace.shared.frontmostApplication,
                          xcode.bundleIdentifier?.hasPrefix("com.apple.dt.Xcode") == true
                    else {
                        throw CaptureError.noXcode
                    }
                    let request = CaptureRequest(capture: capture, xcodeProcessID: xcode.processIdentifier,
                                                 bufferDigest: digest, createdAt: Date())
                    let handoff = try CaptureTransport.publish(request)
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = false
                    NSWorkspace.shared.open(handoff.url, configuration: configuration) { _, error in
                        if error != nil { CaptureTransport.discard(handoff.token) }
                        completionHandler(error)
                    }
                } catch {
                    completionHandler(error)
                }
            }
        } catch {
            completionHandler(error)
        }
        // No writes to invocation.buffer or selections: source always remains untouched.
    }
}
