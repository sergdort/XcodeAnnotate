import AnnotateDomain
import AnnotateHandoff
import CombineFeedback
import Foundation

/// A capture whose file has been resolved, ready for the user to write a message.
public struct ResolvedCapture: Equatable, Sendable {
    public let reference: CodeReference
    /// The complete lines around the selection, for display.
    public let excerpt: SourceExcerpt
    /// The user had only a caret, so the selection is the current line.
    public let isCurrentLine: Bool
    /// The Xcode process to return focus to when the composer closes.
    public let sourceProcessID: Int32

    public init(reference: CodeReference, excerpt: SourceExcerpt, isCurrentLine: Bool, sourceProcessID: Int32) {
        self.reference = reference
        self.excerpt = excerpt
        self.isCurrentLine = isCurrentLine
        self.sourceProcessID = sourceProcessID
    }
}

public struct ComposerDraft: Equatable, Sendable {
    public let capture: ResolvedCapture
    public var message = ""
    /// Why the last copy attempt failed; cleared as soon as the message changes.
    public var problem: CaptureError?

    public init(capture: ResolvedCapture) {
        self.capture = capture
    }

    /// `nil` while the message is blank.
    public var annotation: Annotation? {
        AnnotationMessage(message).map { Annotation(reference: capture.reference, message: $0) }
    }
}

/// The companion app's flow: receive a handoff, resolve its file, compose a message, copy the prompt.
public struct CaptureSession: StateMachine {
    public struct Dependencies: Sendable {
        /// Consumes the handoff and resolves which file the captured selection belongs to.
        public var resolve: @Sendable (URL) async -> Result<ResolvedCapture, CaptureError>
        /// Writes text to the general clipboard; `false` when macOS refuses.
        public var copy: @Sendable (String) async -> Bool
        /// Suspends for as long as the "Copied" confirmation stays on screen.
        public var showConfirmation: @Sendable () async -> Void

        public init(
            resolve: @escaping @Sendable (URL) async -> Result<ResolvedCapture, CaptureError>,
            copy: @escaping @Sendable (String) async -> Bool,
            showConfirmation: @escaping @Sendable () async -> Void
        ) {
            self.resolve = resolve
            self.copy = copy
            self.showConfirmation = showConfirmation
        }
    }

    public enum State: Equatable, Sendable {
        case idle
        case resolving(URL)
        case composing(ComposerDraft)
        /// Invariant: the draft has a valid annotation.
        case copying(ComposerDraft)
        /// The prompt is on the clipboard; briefly confirmed before returning to idle.
        case copied(Annotation)
        case failed(CaptureError)
    }

    public enum Event: Equatable, Sendable {
        case handoffReceived(URL)
        case handoffResolved(URL, Result<ResolvedCapture, CaptureError>)
        case messageChanged(String)
        case submitted
        case cancelled
        case copied
        case copyFailed(CaptureError)
        case confirmationEnded
        case failureAcknowledged
    }

    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    @StateMachineBuilder<State, Event>
    public var body: some StateMachine<State, Event> {
        Self.reducer
        whenResolving
        whenCopying
        whenCopied
    }

    public static var reducer: Reducer<State, Event> {
        Reducer { state, event in
            switch (state, event) {
            case let (_, .handoffReceived(url)):
                // The newest capture wins; an older resolution in flight is ignored below.
                state = .resolving(url)
            case let (.resolving(pending), .handoffResolved(url, result)) where pending == url:
                switch result {
                case let .success(capture): state = .composing(ComposerDraft(capture: capture))
                case let .failure(error): state = .failed(error)
                }
            case (.composing(var draft), let .messageChanged(message)):
                draft.message = message
                draft.problem = nil
                state = .composing(draft)
            case let (.composing(draft), .submitted) where draft.annotation != nil:
                // Policy seam: collecting annotations for a later batch copy would branch here.
                state = .copying(draft)
            case (.composing, .cancelled):
                state = .idle
            case let (.copying(draft), .copied):
                state = draft.annotation.map(State.copied) ?? .idle
            case (.copied, .confirmationEnded):
                state = .idle
            case (.copying(var draft), let .copyFailed(error)):
                draft.problem = error
                state = .composing(draft)
            case (.failed, .failureAcknowledged):
                state = .idle
            default:
                break
            }
        }
    }

    private var whenResolving: OnChange<State, Event, URL> {
        OnChange(of: \.pendingHandoff) { [dependencies] url async in
            await .handoffResolved(url, dependencies.resolve(url))
        }
    }

    private var whenCopying: OnChange<State, Event, String> {
        OnChange(of: \.promptToCopy) { [dependencies] prompt async in
            await dependencies.copy(prompt) ? .copied : .copyFailed(.clipboardWriteFailed)
        }
    }

    private var whenCopied: OnChange<State, Event, Annotation> {
        OnChange(of: \.copiedAnnotation) { [dependencies] _ async in
            await dependencies.showConfirmation()
            return .confirmationEnded
        }
    }
}

public extension CaptureSession.State {
    /// What the app should show; the UI layer renders this and nothing else.
    enum Presentation: Equatable, Sendable {
        case hidden
        case composer(sourceProcessID: Int32)
        case confirmation(Annotation)
        case failure(CaptureError)
    }

    var presentation: Presentation {
        switch self {
        case .idle, .resolving: .hidden
        case let .composing(draft), let .copying(draft): .composer(sourceProcessID: draft.capture.sourceProcessID)
        case let .copied(annotation): .confirmation(annotation)
        case let .failed(error): .failure(error)
        }
    }

    var draft: ComposerDraft? {
        switch self {
        case let .composing(draft), let .copying(draft): draft
        case .idle, .resolving, .copied, .failed: nil
        }
    }

    var isCopying: Bool {
        if case .copying = self { true } else { false }
    }

    internal var pendingHandoff: URL? {
        if case let .resolving(url) = self { url } else { nil }
    }

    internal var copiedAnnotation: Annotation? {
        if case let .copied(annotation) = self { annotation } else { nil }
    }

    internal var promptToCopy: String? {
        if case let .copying(draft) = self { draft.annotation.map(AgentPrompt.render) } else { nil }
    }
}
