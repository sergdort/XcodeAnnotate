import Foundation

/// Text taken from a source buffer together with the range it came from.
public struct CodeSelection: Codable, Hashable, Sendable {
    public let range: SourceRange
    public let text: String

    public init(range: SourceRange, text: String) {
        self.range = range
        self.text = text
    }

    /// Extracts the text between two positions of a buffer given as lines that keep their line endings.
    ///
    /// An empty selection captures the whole current line without its line ending. A real selection
    /// keeps line endings exactly as selected. Returns `nil` when a position lies outside the buffer.
    public static func extract(
        from lines: [String],
        between anchor: SourcePosition,
        and head: SourcePosition
    ) -> CodeSelection? {
        let range = SourceRange(anchor, head)
        if range.isEmpty {
            return currentLine(of: lines, at: range.start.line)
        }
        guard let first = offset(of: range.start, in: lines),
              let last = offset(of: range.end, in: lines)
        else { return nil }
        let text = (lines.joined() as NSString).substring(with: NSRange(location: first, length: last - first))
        return CodeSelection(range: range, text: text)
    }

    private static func currentLine(of lines: [String], at index: Int) -> CodeSelection? {
        guard lines.indices.contains(index) else { return nil }
        var line = lines[index]
        // "\r\n" is a single Swift Character: hasSuffix("\n") misses it, and one removeLast() strips it.
        if line.hasSuffix("\r\n") || line.hasSuffix("\n") || line.hasSuffix("\r") { line.removeLast() }
        let range = SourceRange(
            SourcePosition(line: index, column: 0),
            SourcePosition(line: index, column: (line as NSString).length)
        )
        return CodeSelection(range: range, text: line)
    }

    /// UTF-16 offset of a position in the joined buffer. The position just past the last line is valid.
    private static func offset(of position: SourcePosition, in lines: [String]) -> Int? {
        guard position.line >= 0, position.line <= lines.count, position.column >= 0 else { return nil }
        if position.line == lines.count {
            guard position.column == 0 else { return nil }
        } else if position.column > (lines[position.line] as NSString).length {
            return nil
        }
        return lines.prefix(position.line).reduce(0) { $0 + ($1 as NSString).length } + position.column
    }
}
