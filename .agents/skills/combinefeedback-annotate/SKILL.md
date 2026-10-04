---
name: combinefeedback-annotate
description: This repo's CombineFeedback conventions — module boundaries, dependency injection, store ownership, AppKit presentation, view binding, testing. Use ALONGSIDE combinefeedback-state-machines (modeling) and combinefeedback-state-machine-testing (test theory) whenever building, changing, or reviewing CombineFeedback code in Annotate for Agent.
metadata:
  short-description: This repo's CombineFeedback conventions.
---

# CombineFeedback in Annotate for Agent

CombineFeedback has no opinion on dependency injection, store ownership or
presentation. This repo decided each one. Follow these decisions instead of
working out alternatives per change.

Division of labor:

- `combinefeedback-state-machines` covers how to model state, events, reducers and feedbacks.
- `combinefeedback-state-machine-testing` covers destination testing and `TestStore`.
- **This skill** covers what this repo decided.

The reference machine is `CaptureSession` in
`XcodeAgentAnnotate/Modules/AnnotateFeature/Sources/CaptureSession.swift`.
The code is the source of truth. If you change a convention, update this skill
in the same change.

## Module Boundaries

| Module | May import | Holds |
|---|---|---|
| `AnnotateDomain` | Foundation | Pure value types and the clipboard format (`AgentPrompt`) |
| `AnnotateHandoff` | Domain, AppKit | Extension → app transport, `CaptureError` |
| `AnnotateFeature` | Domain, Handoff, CombineFeedback | State machines |
| `EditorExtension` | Domain, Handoff, XcodeKit | **Never CombineFeedback** |
| App target | everything | Store owner, live dependencies, AppKit presenter, SwiftUI views |

- Modules are Tuist `.staticLibrary` targets declared with the `module(_:dependencies:)` helper in `Project.swift`.
- CombineFeedback is an Xcode-native package in `Project.swift`. It is pinned by revision, referenced with `.package(product:)`, and its lockfile is `.package.resolved`. Do not move it to `Tuist/Package.swift`: Tuist reports a circular dependency through the `xctest-dynamic-overlay` shim.
- Machines stay free of AppKit, AX and the pasteboard. Those belong behind dependencies.

## Dependencies

Each machine declares a nested `Dependencies` struct of `@Sendable` async
closures and receives it through `init`. This repo does not use a
dependency-injection library.

```swift
public struct Dependencies: Sendable {
    public var resolve: @Sendable (URL) async -> Result<ResolvedCapture, CaptureError>
    public var copy: @Sendable (String) async -> Bool
    public var showConfirmation: @Sendable () async -> Void
}
```

- Closures return outcomes (`Result`, `Bool`), never `throws`. Map errors to `CaptureError` at the live boundary.
- The live values are `static let live` in `App/LiveDependencies.swift`. Work that must run on the main thread wraps itself in `await MainActor.run { … }`.
- Time is a dependency too. For example, `showConfirmation` sleeps in live code and is `{}` in tests.
- Feedback closures capture `[dependencies]` and never read `self`.

## Machine Shape

- `State` is an `enum` of exclusive modes, `Equatable, Sendable`. Each case carries only the data it needs (`composing(ComposerDraft)`).
- `Event` is `Equatable, Sendable` and covers user intent, external input and effect results. It is not `@CasePathable` until a `Scope`/`OnEvent` needs it.
- `body` lists `Self.reducer` first, then the named private effects (`whenResolving`, `whenCopying`, …).
- `public static var reducer` exists so Tier-1 tests can call it directly.
- The reducer switches on `(state, event)` and falls through with `default: break`. An event in the wrong state is ignored, not an error.
- Effects are `OnChange` over **internal derived projections** of the state enum (`pendingHandoff`, `promptToCopy`, `copiedAnnotation`). Leaving the state cancels the work. Do not store parallel request flags.
- **Stale results:** the result event carries the request's identity, for example `handoffResolved(URL, Result)`. The reducer accepts it only if that identity still matches (`case let (.resolving(pending), .handoffResolved(url, _)) where pending == url`).
- Newer external input wins: `handoffReceived` replaces whatever state is current.

## Presentation and Store Ownership

- The app has **one** `Store`, owned by `AppDelegate` for the app's whole lifetime (`App/XcodeAgentAnnotateApp.swift`). Views and presenters receive it; they never construct one.
- Machines do not own windows or navigation. The state exposes a derived `Presentation` enum (`hidden`, `composer`, `confirmation`, `failure`), and `Capture/CapturePresenter.swift` renders only that.

```swift
store.publisher.map(\.presentation).removeDuplicates()
    .receive(on: DispatchQueue.main)          // async effects emit off-main
    .sink { [weak self] p in MainActor.assumeIsolated { self?.render(p) } }
```

- Window/focus side effects such as returning focus to Xcode belong in the presenter. It decides from the previous and next `Presentation`, not from new machine state.
- New UI surfaces get a `Presentation` case plus a SwiftUI view hosted in `FloatingPanel`. The app shell stays AppKit; the reasons are in `XcodeAgentAnnotate/README.md`.

## View Binding

```swift
@StoreBinding<CaptureSession.State, CaptureSession.Event>
private var state: CaptureSession.State

init(store: Store<CaptureSession.State, CaptureSession.Event>) { _state = StoreBinding(store) }
```

- Generic arguments must be written out explicitly, because they cannot be inferred.
- Send events with `$state.send(_:)` or `$state.action(for:)`. Bind text fields with a hand-rolled `Binding(get:set:)` that sends `.messageChanged`.
- Child views take plain data and callbacks, never the store (`ConfirmationView(annotation:)`, `FailureView(error:dismiss:)`).

## Testing

All tests live in one unhosted target, `XcodeAgentAnnotate/Tests/`, which depends on the modules plus `CombineFeedbackTest`. `CaptureSessionTests.swift` is the reference.

- **Tier 1:** call `CaptureSession.reducer(&state, event)` for transitions and guards, such as blank-message submit, stale resolution and cancel.
- **Tier 2:** `TestStore` with stub closures for complete flows. Use `await store.wait { … }` to wait for the user-visible destination (`presentation`, `draft?.problem`, `.idle`).
- Record side effects with a small `actor` spy (`Clipboard`), and assert the exact strings written.
- Never sleep in tests. Inject time through dependencies.

## Future Seam: Collecting Annotations

The `submitted` transition is the single place where "copy now" could become
"add to a collection". When that happens:

- the state grows into a struct holding `[Annotation]` plus the capture mode;
- `AgentPrompt` renders a batch;
- the extension, the handoff and the resolver stay unchanged.

If capture becomes a child machine, compose it with `Scope`. That makes `Event` `@CasePathable` and requires importing CasePaths.
