import Foundation

/// A selection pinned to the local file it was taken from.
public struct CodeReference: Codable, Hashable, Sendable {
    public let file: URL
    public let selection: CodeSelection

    public init(file: URL, selection: CodeSelection) {
        self.file = file
        self.selection = selection
    }
}

/// A non-blank message for the agent, trimmed the same way JavaScript's `String.prototype.trim()` does.
public struct AnnotationMessage: Codable, Hashable, Sendable {
    public let text: String

    /// Returns `nil` when the input is blank.
    public init?(_ raw: String) {
        let text = raw.trimmingCharacters(in: Self.whitespace)
        guard !text.isEmpty else { return nil }
        self.text = text
    }

    /// Matches JavaScript's trim(): includes the BOM, excludes U+001C...U+001F.
    private static let whitespace = CharacterSet(charactersIn:
        "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{00A0}\u{1680}" +
            "\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}" +
            "\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
}

/// What the user wants the agent to know about a piece of code.
public struct Annotation: Codable, Hashable, Sendable {
    public let reference: CodeReference
    public let message: AnnotationMessage

    public init(reference: CodeReference, message: AnnotationMessage) {
        self.reference = reference
        self.message = message
    }
}
