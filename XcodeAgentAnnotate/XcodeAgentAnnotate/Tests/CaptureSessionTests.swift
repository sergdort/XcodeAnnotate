import AnnotateDomain
import AnnotateFeature
import AnnotateHandoff
import CombineFeedback
import CombineFeedbackTest
import Foundation
import Testing

struct CaptureSessionTests {
    typealias State = CaptureSession.State

    private static let handoff = URL(string: "xcode-agent-annotate://capture/first")!
    private static let capture = ResolvedCapture(
        reference: CodeReference(
            file: URL(fileURLWithPath: "/a.swift"),
            selection: CodeSelection(range: SourceRange(.init(line: 0, column: 0), .init(line: 0, column: 1)), text: "x")
        ),
        excerpt: SourceExcerpt(firstLine: 0, lines: ["x"]),
        isCurrentLine: false,
        sourceProcessID: 42
    )

    private actor Clipboard {
        let accepts: Bool
        private(set) var writes: [String] = []
        init(accepts: Bool) {
            self.accepts = accepts
        }

        func write(_ text: String) -> Bool {
            writes.append(text)
            return accepts
        }
    }

    private static func store(
        resolving result: Result<ResolvedCapture, CaptureError> = .success(capture),
        clipboard: Clipboard = Clipboard(accepts: true)
    ) -> TestStore<State, CaptureSession.Event> {
        TestStore(initial: .idle, machine: CaptureSession(dependencies: .init(
            resolve: { _ in result },
            copy: { await clipboard.write($0) },
            showConfirmation: {}
        )))
    }

    // MARK: Feedback loop

    @Test func copiesTheRenderedPromptOnceAndConfirmsBeforeReturningToIdle() async {
        let clipboard = Clipboard(accepts: true)
        let store = Self.store(clipboard: clipboard)

        store.send(.handoffReceived(Self.handoff))
        await store.wait { $0 == .composing(ComposerDraft(capture: Self.capture)) }
        store.send(.messageChanged(" explain "))
        store.send(.submitted)
        await store.wait { $0.isCopying }
        await store.wait { if case .confirmation = $0.presentation { true } else { false } }
        await store.wait { $0 == .idle }

        #expect(await clipboard.writes ==
            ["File: /a.swift\nSelection: 1:1-1:2 (1-based, end exclusive)\n\n```\nx\n```\n\nMessage: explain"])
    }

    @Test func refusedClipboardWriteKeepsTheDraftWithAProblem() async {
        let store = Self.store(clipboard: Clipboard(accepts: false))

        store.send(.handoffReceived(Self.handoff))
        await store.wait { $0.draft != nil }
        store.send(.messageChanged("explain"))
        store.send(.submitted)

        await store.wait { $0.draft?.problem == .clipboardWriteFailed && !$0.isCopying }
        #expect(store.state.draft?.message == "explain")
    }

    @Test func resolutionFailureIsPresentedUntilAcknowledged() async {
        let clipboard = Clipboard(accepts: true)
        let store = Self.store(resolving: .failure(.accessibilityRequired), clipboard: clipboard)

        store.send(.handoffReceived(Self.handoff))
        await store.wait { $0.presentation == .failure(.accessibilityRequired) }
        store.send(.failureAcknowledged)
        await store.wait { $0 == .idle }

        #expect(await clipboard.writes.isEmpty)
    }

    // MARK: Transitions

    @Test func onlyAValidMessageCanBeSubmitted() {
        var state = State.composing(ComposerDraft(capture: Self.capture))
        CaptureSession.reducer(&state, .messageChanged(" \n"))
        CaptureSession.reducer(&state, .submitted)
        #expect(!state.isCopying)

        CaptureSession.reducer(&state, .messageChanged("explain"))
        CaptureSession.reducer(&state, .submitted)
        #expect(state.isCopying)
    }

    @Test func editingClearsTheProblemAndCancelReturnsFocusWithoutCopying() {
        var draft = ComposerDraft(capture: Self.capture)
        draft.problem = .clipboardWriteFailed
        var state = State.composing(draft)

        CaptureSession.reducer(&state, .messageChanged("e"))
        #expect(state.draft?.problem == nil)

        CaptureSession.reducer(&state, .cancelled)
        #expect(state == .idle)
    }

    @Test func aNewerHandoffWinsOverAStaleResolution() throws {
        let newer = try #require(URL(string: "xcode-agent-annotate://capture/second"))
        var state = State.idle
        CaptureSession.reducer(&state, .handoffReceived(Self.handoff))
        CaptureSession.reducer(&state, .handoffReceived(newer))
        CaptureSession.reducer(&state, .handoffResolved(Self.handoff, .success(Self.capture)))
        #expect(state == .resolving(newer))
    }
}
