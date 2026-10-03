import CryptoKit
import Foundation

struct SourcePosition: Codable, Equatable, Comparable {
    let line: Int
    let column: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.line == rhs.line ? lhs.column < rhs.column : lhs.line < rhs.line
    }
}

struct CodeCapture: Codable, Equatable {
    let start: SourcePosition
    let end: SourcePosition
    let snippet: String

    /// XcodeKit columns are treated as NSString/UTF-16 offsets, not Swift Characters.
    /// Keep line endings in selected text; only the empty-selection fallback strips them.
    static func capture(lines: [String], start: SourcePosition, end: SourcePosition) throws -> Self {
        guard !lines.isEmpty else { throw CaptureError.invalidSelection }
        var lower = min(start, end)
        var upper = max(start, end)
        if lower == upper {
            guard lines.indices.contains(lower.line) else { throw CaptureError.invalidSelection }
            var line = lines[lower.line]
            if line.hasSuffix("\r\n") { line.removeLast() } // CRLF is one Swift Character.
            else if line.hasSuffix("\n") || line.hasSuffix("\r") { line.removeLast() }
            lower = SourcePosition(line: lower.line, column: 0)
            upper = SourcePosition(line: lower.line, column: (line as NSString).length)
            return Self(start: lower, end: upper, snippet: line)
        }

        func offset(_ position: SourcePosition) throws -> Int {
            guard position.line >= 0, position.line <= lines.count, position.column >= 0 else {
                throw CaptureError.invalidSelection
            }
            if position.line == lines.count {
                guard position.column == 0 else { throw CaptureError.invalidSelection }
            } else if position.column > (lines[position.line] as NSString).length {
                throw CaptureError.invalidSelection
            }
            return lines.prefix(position.line).reduce(0) { $0 + ($1 as NSString).length } + position.column
        }
        let first = try offset(lower)
        let last = try offset(upper)
        let text = lines.joined() as NSString
        return Self(start: lower, end: upper,
                    snippet: text.substring(with: NSRange(location: first, length: last - first)))
    }

    var selectionDescription: String {
        "\(start.line + 1):\(start.column + 1)-\(end.line + 1):\(end.column + 1) (1-based, end exclusive)"
    }

    func annotation(path: String, message: String) -> String {
        var longest = 2
        var run = 0
        for character in snippet {
            run = character == "`" ? run + 1 : 0
            longest = max(longest, run)
        }
        let fence = String(repeating: "`", count: longest + 1)
        return ["File: \(path)", "Selection: \(selectionDescription)", "", fence, snippet,
                fence, "", "Message: \(Self.trimMessage(message))"].joined(separator: "\n")
    }

    static func trimMessage(_ message: String) -> String {
        // Match JavaScript String.trim(), including BOM but excluding U+001C...U+001F.
        let whitespace = CharacterSet(charactersIn:
            "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{00A0}\u{1680}" +
                "\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}" +
                "\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
        return message.trimmingCharacters(in: whitespace)
    }
}

struct CaptureRequest: Codable {
    let capture: CodeCapture
    let xcodeProcessID: Int32
    let bufferDigest: String
    let createdAt: Date

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum CaptureError: LocalizedError {
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

    var errorDescription: String? {
        switch self {
        case .invalidSelection: return "Xcode supplied an unsupported source selection. The clipboard was not changed."
        case .multipleSelections: return "Use a single selection or caret. Multiple selections are not supported yet."
        case .noXcode: return "Invoke this command from the active Xcode source editor."
        case .accessibilityRequired: return "Grant Annotate for Agent Accessibility access in System Settings, then invoke the Xcode command again."
        case let .unverifiedEditor(reason): return "Could not verify a single active source editor (\(reason)). Close split editors, comparison views, and the debug console, then focus the source editor and try again. The clipboard was not changed."
        case .noLocalFile: return "Could not resolve a saved local source file. Save the file, focus its editor, and try again."
        case .invalidRequest: return "The capture request is invalid or expired. Invoke the Xcode command again."
        case .handoffFailed: return "Could not open Annotate for Agent. Install and open the containing app first."
        case .payloadTooLarge: return "The capture exceeds the prototype’s 16 MB handoff limit. Select a smaller section."
        case .clipboardWriteFailed: return "macOS could not write the annotation to the clipboard. Try copying again."
        }
    }
}
