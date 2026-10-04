import AnnotateDomain
import AnnotateFeature
import CombineFeedback
import SwiftUI

/// The Spotlight-style message panel: message field, source, highlighted code and keyboard hints.
struct ComposerView: View {
    @StoreBinding<CaptureSession.State, CaptureSession.Event> private var state: CaptureSession.State
    @FocusState private var messageFocused: Bool

    init(store: Store<CaptureSession.State, CaptureSession.Event>) {
        _state = StoreBinding(store)
    }

    var body: some View {
        if let draft = state.draft {
            content(draft)
        }
    }

    private func content(_ draft: ComposerDraft) -> some View {
        let capture = draft.capture
        let canCopy = draft.annotation != nil && !state.isCopying
        return PanelCard(width: 680) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 17))
                        .foregroundStyle(Palette.secondary)
                    TextField("Ask your agent about this code", text: Binding(
                        get: { draft.message },
                        set: { $state.send(.messageChanged($0)) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.ink)
                    .focused($messageFocused)
                    .onSubmit { $state.send(.submitted) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Rectangle().fill(Palette.hairline).frame(height: 1)

                SourceRow(capture: capture)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                CodeWell(
                    lines: capture.excerpt.layout(selecting: capture.reference.selection.range),
                    file: capture.reference.file
                )
                .padding(.horizontal, 12)

                HStack(spacing: 16) {
                    footerText(draft)
                    Spacer(minLength: 12)
                    KeyButton(title: "Cancel", key: "esc", action: $state.action(for: .cancelled))
                        .keyboardShortcut(.cancelAction)
                    KeyButton(title: "Copy", key: "↩", prominent: true, action: $state.action(for: .submitted))
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canCopy)
                        .opacity(canCopy ? 1 : 0.4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .defaultFocus($messageFocused, true)
        // The view appears before its panel becomes key, so focus again once it does.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            messageFocused = true
        }
    }

    @ViewBuilder
    private func footerText(_ draft: ComposerDraft) -> some View {
        if let problem = draft.problem {
            Text(problem.localizedDescription)
                .font(.system(size: 12))
                .foregroundStyle(.red)
        } else {
            Text(draft.capture.isCurrentLine
                ? "Nothing selected — using the current line"
                : "Copies file, range, code and message to the clipboard")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
        }
    }
}

/// `Project / Sources / File.swift` on the left, the selected range on the right.
private struct SourceRow: View {
    let capture: ResolvedCapture

    var body: some View {
        let file = capture.reference.file
        let folders = file.deletingLastPathComponent().pathComponents.suffix(2)
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
            (Text(folders.map { "\($0) / " }.joined()).foregroundStyle(Palette.secondary)
                + Text(file.lastPathComponent).fontWeight(.semibold).foregroundStyle(Palette.ink))
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.head)
                .help(file.path)
            Spacer(minLength: 12)
            Text(rangeLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.secondary)
        }
    }

    private var rangeLabel: String {
        let range = capture.reference.selection.range
        if capture.isCurrentLine { return "Line \(range.start.line + 1) · current line" }
        return "\(range.start.line + 1):\(range.start.column + 1) – \(range.end.line + 1):\(range.end.column + 1)"
    }
}

/// Line-numbered, syntax-highlighted code with the selection marked and the rest faded.
private struct CodeWell: View {
    let lines: [ExcerptLine]
    let file: URL
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlighted: [[CodeSegment]]?

    private static let rowHeight: CGFloat = 20

    var body: some View {
        let segments = highlighted ?? CodeHighlighter.plain(lines)
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(zip(lines, segments).enumerated()), id: \.offset) { _, row in
                    LineRow(line: row.0, segments: row.1)
                }
            }
            .padding(.vertical, 8)
            .padding(.trailing, 16)
        }
        .scrollIndicators(.automatic)
        .frame(height: min(CGFloat(lines.count) * Self.rowHeight + 16, 280))
        .background(Palette.well, in: RoundedRectangle(cornerRadius: 10))
        .task(id: HighlightRequest(lines: lines, file: file, dark: colorScheme == .dark)) {
            highlighted = await CodeHighlighter.highlight(lines, file: file, dark: colorScheme == .dark)
        }
    }

    private struct HighlightRequest: Hashable {
        let lines: [ExcerptLine]
        let file: URL
        let dark: Bool
    }

    private struct LineRow: View {
        let line: ExcerptLine
        let segments: [CodeSegment]

        var body: some View {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(line.selected.isEmpty ? Color.clear : Palette.accent)
                    .frame(width: 2)
                Text(verbatim: "\(line.number)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.lineNumber)
                    .frame(width: 34, alignment: .trailing)
                    .padding(.trailing, 14)
                Text(CodeHighlighter.render(segments, selected: line.selected))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Palette.ink)
                    .fixedSize()
            }
            .frame(height: CodeWell.rowHeight)
        }
    }
}
