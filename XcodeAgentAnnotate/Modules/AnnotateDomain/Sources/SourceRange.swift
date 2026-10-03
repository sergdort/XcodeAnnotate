/// A zero-based position in a source buffer.
///
/// Columns are UTF-16 offsets, matching XcodeKit, not Swift `Character` counts.
public struct SourcePosition: Codable, Hashable, Comparable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.line == rhs.line ? lhs.column < rhs.column : lhs.line < rhs.line
    }
}

/// A half-open range of source positions, always ordered so `start <= end`.
public struct SourceRange: Codable, Hashable, Sendable {
    public let start: SourcePosition
    public let end: SourcePosition

    /// Accepts the endpoints in either order, as editors report backwards selections.
    public init(_ anchor: SourcePosition, _ head: SourcePosition) {
        start = min(anchor, head)
        end = max(anchor, head)
    }

    public var isEmpty: Bool {
        start == end
    }

    /// `26:9-30:6 (1-based, end exclusive)`, the format the VS Code and JetBrains extensions use.
    public var oneBasedDescription: String {
        "\(start.line + 1):\(start.column + 1)-\(end.line + 1):\(end.column + 1) (1-based, end exclusive)"
    }
}
