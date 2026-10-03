/// The clipboard text an agent receives, byte-for-byte compatible with the VS Code and JetBrains extensions.
public enum AgentPrompt {
    public static func render(_ annotation: Annotation) -> String {
        let reference = annotation.reference
        let snippet = reference.selection.text
        let fence = fence(for: snippet)
        return [
            "File: \(reference.file.path)",
            "Selection: \(reference.selection.range.oneBasedDescription)",
            "",
            fence,
            snippet,
            fence,
            "",
            "Message: \(annotation.message.text)",
        ].joined(separator: "\n")
    }

    /// At least three backticks, and always longer than any backtick run inside the snippet.
    private static func fence(for snippet: String) -> String {
        var longest = 2
        var run = 0
        for character in snippet {
            run = character == "`" ? run + 1 : 0
            longest = max(longest, run)
        }
        return String(repeating: "`", count: longest + 1)
    }
}
