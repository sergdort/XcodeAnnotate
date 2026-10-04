import Foundation

/// The complete lines a selection touches, kept so the selection can be shown in context.
public struct SourceExcerpt: Codable, Hashable, Sendable {
    /// Zero-based buffer line of `lines.first`.
    public let firstLine: Int
    /// Lines without their line endings.
    public let lines: [String]

    public init(firstLine: Int, lines: [String]) {
        self.firstLine = firstLine
        self.lines = lines
    }

    /// The lines of `buffer` (which keep their line endings) that `range` covers.
    ///
    /// A multi-line selection ending at column 0 does not include that last line.
    public static func covering(_ range: SourceRange, in buffer: [String]) -> SourceExcerpt? {
        var last = range.end.line
        if range.end.column == 0, last > range.start.line { last -= 1 }
        guard range.start.line >= 0, last < buffer.count, range.start.line <= last else { return nil }
        let lines = buffer[range.start.line ... last].map { line in
            var line = line
            // "\r\n" is a single Swift Character: hasSuffix("\n") misses it, and one removeLast() strips it.
            if line.hasSuffix("\r\n") || line.hasSuffix("\n") || line.hasSuffix("\r") { line.removeLast() }
            return line
        }
        return SourceExcerpt(firstLine: range.start.line, lines: lines)
    }

    /// Lines dedented by their common indentation, each with the UTF-16 columns `range` selects on it.
    public func layout(selecting range: SourceRange) -> [ExcerptLine] {
        let indent = commonIndentation
        return lines.enumerated().map { offset, line in
            let number = firstLine + offset
            let length = (line as NSString).length
            let text = length < indent ? "" : (line as NSString).substring(from: indent)
            let textLength = (text as NSString).length
            let start = number == range.start.line ? range.start.column : 0
            let end = number == range.end.line ? range.end.column : length
            let lower = min(max(start - indent, 0), textLength)
            let upper = min(max(end - indent, lower), textLength)
            return ExcerptLine(number: number + 1, text: text, selected: lower ..< upper)
        }
    }

    /// UTF-16 length of the leading spaces and tabs shared by every non-blank line.
    private var commonIndentation: Int {
        let indents = lines
            .filter { !$0.allSatisfy { $0 == " " || $0 == "\t" } }
            .map { $0.prefix { $0 == " " || $0 == "\t" } }
        guard var common = indents.first.map(String.init) else { return 0 }
        for indent in indents.dropFirst() {
            common = String(zip(common, indent).prefix { $0 == $1 }.map(\.0))
        }
        return (common as NSString).length
    }
}

/// One display row of an excerpt.
public struct ExcerptLine: Hashable, Sendable {
    /// One-based line number.
    public let number: Int
    public let text: String
    /// Selected UTF-16 columns of `text`.
    public let selected: Range<Int>

    public init(number: Int, text: String, selected: Range<Int>) {
        self.number = number
        self.text = text
        self.selected = selected
    }
}
