import AnnotateDomain
import CryptoKit
import Foundation

/// What the editor extension knows about a capture. The file path is resolved later by the companion app.
public struct CaptureRequest: Codable, Equatable, Sendable {
    public let selection: CodeSelection
    /// The complete lines around the selection, for display only.
    public let excerpt: SourceExcerpt
    /// The user had only a caret, so the selection is the current line.
    public let isCurrentLine: Bool
    public let xcodeProcessID: Int32
    /// SHA-256 of the whole buffer, used to confirm the focused editor still shows the captured text.
    public let bufferDigest: String
    public let createdAt: Date

    public init(
        selection: CodeSelection,
        excerpt: SourceExcerpt,
        isCurrentLine: Bool,
        xcodeProcessID: Int32,
        bufferDigest: String,
        createdAt: Date
    ) {
        self.selection = selection
        self.excerpt = excerpt
        self.isCurrentLine = isCurrentLine
        self.xcodeProcessID = xcodeProcessID
        self.bufferDigest = bufferDigest
        self.createdAt = createdAt
    }

    public static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
