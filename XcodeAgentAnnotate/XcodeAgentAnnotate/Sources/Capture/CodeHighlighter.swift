import AnnotateDomain
import AppKit
import HighlightSwift
import SwiftUI

/// A run of code text with an optional syntax color.
struct CodeSegment: Hashable {
    var text: String
    var color: Color?
}

/// Syntax-colors excerpt lines with highlight.js (via HighlightSwift), keeping them line-aligned.
enum CodeHighlighter {
    private static let highlight = Highlight()

    /// Uncolored segments, shown until highlighting finishes or when it is unavailable.
    static func plain(_ lines: [ExcerptLine]) -> [[CodeSegment]] {
        lines.map { [CodeSegment(text: $0.text, color: nil)] }
    }

    /// Per-line colored segments, or `nil` when the language is unknown or highlighting fails.
    static func highlight(_ lines: [ExcerptLine], file: URL, dark: Bool) async -> [[CodeSegment]]? {
        guard let language = language(for: file) else { return nil }
        let text = lines.map(\.text).joined(separator: "\n")
        // HighlightSwift trims surrounding whitespace, so color only the trimmed middle and re-attach the rest.
        let leading = text.prefix { $0.isWhitespace }
        let body = text.dropFirst(leading.count)
        let trailing = body.reversed().prefix { $0.isWhitespace }
        let trimmed = String(body.dropLast(trailing.count))
        guard !trimmed.isEmpty,
              let colored = try? await highlight.attributedText(
                  trimmed, language: language, colors: dark ? .dark(.xcode) : .light(.xcode)
              ),
              String(colored.characters) == trimmed
        else { return nil }

        var pieces = [CodeSegment(text: String(leading), color: nil)]
        for run in colored.runs {
            pieces.append(CodeSegment(text: String(colored[run.range].characters),
                                      color: run.appKit.foregroundColor.map { Color(nsColor: $0) }))
        }
        pieces.append(CodeSegment(text: String(trailing.reversed()), color: nil))

        let split = splitIntoLines(pieces)
        guard split.count == lines.count,
              zip(split, lines).allSatisfy({ $0.map(\.text).joined() == $1.text })
        else { return nil }
        return split
    }

    /// The line as styled text, with everything outside the selected UTF-16 columns faded.
    static func render(_ segments: [CodeSegment], selected: Range<Int>) -> AttributedString {
        var result = AttributedString()
        var offset = 0
        for segment in segments {
            let text = segment.text as NSString
            let range = offset ..< offset + text.length
            offset = range.upperBound
            // Split the segment where the selection starts and ends.
            let cuts = [range.lowerBound, selected.lowerBound, selected.upperBound, range.upperBound]
                .filter { range.contains($0) || $0 == range.upperBound }
                .sorted()
            for (start, end) in zip(cuts, cuts.dropFirst()) where start < end {
                var piece = AttributedString(text.substring(with: NSRange(location: start - range.lowerBound,
                                                                          length: end - start)))
                if selected.contains(start) {
                    piece.swiftUI.foregroundColor = segment.color
                } else {
                    piece.swiftUI.foregroundColor = (segment.color ?? Palette.ink).opacity(0.38)
                }
                result += piece
            }
        }
        return result
    }

    private static func splitIntoLines(_ pieces: [CodeSegment]) -> [[CodeSegment]] {
        var lines: [[CodeSegment]] = [[]]
        for piece in pieces {
            for (index, part) in piece.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if index > 0 { lines.append([]) }
                if !part.isEmpty { lines[lines.count - 1].append(CodeSegment(text: String(part), color: piece.color)) }
            }
        }
        return lines
    }

    /// highlight.js language names by file extension; `nil` leaves the code uncolored.
    static func language(for file: URL) -> String? {
        switch file.pathExtension.lowercased() {
        case "swift", "swiftinterface": "swift"
        case "m", "mm", "h": "objectivec"
        case "c": "c"
        case "cpp", "cc", "cxx", "hpp", "hh", "metal": "cpp"
        case "json": "json"
        case "xml", "plist", "storyboard", "xib", "entitlements", "html": "xml"
        case "md", "markdown": "markdown"
        case "yml", "yaml": "yaml"
        case "sh", "zsh", "bash": "bash"
        case "py": "python"
        case "js", "mjs": "javascript"
        case "ts": "typescript"
        case "rb": "ruby"
        default: nil
        }
    }
}
