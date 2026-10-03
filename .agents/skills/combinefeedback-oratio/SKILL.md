---
name: combinefeedback-oratio
description: Oratio-specific CombineFeedback patterns — navigation, dependencies, store lifetime, composition, testing harness. Use ALONGSIDE combinefeedback-state-machines (modeling) and combinefeedback-state-machine-testing (test theory) whenever building, changing, or reviewing CombineFeedback code in this repo, or adopting CombineFeedback in a new screen.
metadata:
  short-description: This repo's CombineFeedback conventions.
---

# CombineFeedback in Oratio

CombineFeedback is unopinionated about navigation, dependency injection, store
ownership, and testing. This repo made specific decisions about each. Follow
them; do not re-derive alternatives per screen.

Division of labor between the three skills:

- `combinefeedback-state-machines` — how to model state, events, reducers,
  feedback lifecycles. Read it for design work.
- `combinefeedback-state-machine-testing` — destination testing theory and
  `TestStore` usage. Read it before writing machine tests.
- **This skill** — what this repo decided where the library has no opinion.

The reference implementation is the Reader Library screen:
`Projects/Features/Reader/Library/` (three machines), consumed by
`ReaderLibraryView.swift`, wired in
`Projects/OratioApp/Sources/Navigation/ReaderNavigationView.swift`, tested in
`Projects/Features/Tests/ReaderTests/`. Snippets below are condensed from those
files — when in doubt, the code is the source of truth.

## Keeping This Skill Current

This skill is normative, and it only stays useful if it matches reality. When a
pattern here is superseded — a new convention agreed in review, a better
abstraction adopted, or a rule found no longer viable — update this skill **in
the same change** that lands the new pattern. Record the rejected alternative
and its reasoning in gnosis; do not leave a stale rule standing here.

## Navigation

Machines never own routes, paths, or modal state. Navigation crosses the
machine boundary as a feature-owned struct of `@MainActor @Sendable` closures,
injected at machine init. The seam lives in the feature
(`Projects/Features/Reader/Library/LibraryNavigation.swift`):

```swift
public struct LibraryNavigation: Sendable {
    public var showDocument: @MainActor @Sendable (UUID) -> Void
    public var showStarterBook: @MainActor @Sendable (StarterBookOffer) -> Void
    public var showWelcomeTour: @MainActor @Sendable () -> Void
    public var showPaywall: @MainActor @Sendable () -> Void
}
```

The composition root fills it with coordinator calls
(`ReaderNavigationView.makeLibraryNavigation(for:)`); the coordinator
(`ReaderCoordinator`) still owns route identity and destination
ViewModel/Store construction:

```swift
LibraryNavigation(
    showDocument: { coordinator.showDocument(id: $0) },
    showStarterBook: { coordinator.showStarterBook($0) },
    showWelcomeTour: { coordinator.showWelcomeTour() },
    showPaywall: { coordinator.showImportPaywall() }
)
```

Child machines receive only the single closure they need, not the whole
navigation struct (`DocumentImportMachine` takes `showPaywall` only).

There are two navigation patterns, and the choice is a rule, not taste:

**(a) Pure user intent → `SideEffect`.** When the event alone is the complete
navigation decision — no state consulted, no async gating — switch on events in
a fire-and-forget `SideEffect` (`ReaderLibraryMachine.navigationEffect`):

```swift
private var navigationEffect: SideEffect<State, Event> {
    SideEffect { [navigation] _, event in
        switch event {
        case let .documentSelected(document):
            await navigation.showDocument(document.id)
        case let .starterBook(.tapped(offer)):
            await navigation.showStarterBook(offer)
        case .welcomeTourTapped:
            await navigation.showWelcomeTour()
        default:
            break
        }
    }
}
```

**(b) Reducer-computed outcome → request state + `OnChange` + acknowledgment
event.** When "navigate" is decided by the reducer from state × event — gated
on entitlement, or reached after async resolution — model it as optional
request state. `DocumentImportMachine` shows the paywall this way. The reducer
sets `paywallRequest` from two converging paths (known-free at tap time, and
free after async entitlement verification):

```swift
// Path 1: tap while entitlement is already known to be .free
case .free:
    state.flow = .idle
    state.paywallRequest = .init()

// Path 2: .entitlementRefreshed(snapshot) resolves .free after verification
case .free:
    state.flow = .idle
    state.paywallRequest = .init()
```

The effect observes the request and acknowledges with an event the reducer
uses to nil it out:

```swift
private var paywallEffect: OnChange<State, Event, PaywallRequest> {
    OnChange(of: \.paywallRequest) { [showPaywall] _ in
        await showPaywall()
        return .paywallPresented   // reducer sets paywallRequest = nil
    }
}
```

Why (b) cannot be a `SideEffect`: `SideEffect` receives the **post-reduction**
state paired with the event, so a `SideEffect` paywall would have to re-derive
"the reducer chose paywall" by duplicating the entitlement/flow policy across
every triggering event — and post-reduction state cannot always distinguish
"chose paywall" from "ignored the event". Request state also keeps the
navigation decision assertable in pure, synchronous reducer tests, and the
acknowledgment event makes a re-trigger a fresh change `OnChange` can see.

Do not add completion callbacks from destination screens back to a machine.
The library reloads itself because its `onAppear` fires again after a
navigation pop; such a callback existed and was removed (gnosis `arnjee`).

## Dependencies

Feature machines resolve Domain use-case protocols or focused capabilities, never
repositories or persistence stores, and never construct concrete use cases. Follow
[Dependency Injection](../app-architecture/references/dependency-injection.md)
for constructor injection and split keys. Current Reader examples:

```swift
@Dependency(\.readerLibraryUseCase) var readerLibraryUseCase
@Dependency(\.documentImportUseCase) var documentImportUseCase
@Dependency(\.plusEntitlementUseCase) var plusEntitlementUseCase
```

- Resolution happens at `Store` construction and **does** respect an enclosing
  `withDependencies` scope, including through `Scope`-built child machines.
  Verified empirically (gnosis `fpsmyk`) — do not re-litigate this.
- Feedback closures capture the resolved value by name — `[readerLibraryUseCase]`,
  `[plusEntitlementUseCase]` — never re-read `self` inside the closure.
- Machine `init` parameters are reserved for navigation closures and parent
  policy (`DocumentImportMachine(showPaywall:)`). Services never come through
  `init`.
- Domain owns `TestDependencyKey` with unimplemented test/preview values;
  OratioApp supplies live construction. See
  `Projects/Domain/OratioDomain/UseCases/ReaderLibraryUseCase.swift` and
  `Projects/OratioApp/Sources/Dependencies/LiveDependencies.swift`.

`Dependencies` remains an external dependency of `OratioDomain` only (see
AGENTS.md); feature modules get it transitively.

## Store Lifetime and Module Boundaries

Production Feature screens never construct a `Store` (preview/test scopes are
explicit exceptions below). They export:

- public machine types (`ReaderLibraryMachine` and its `State`/`Event`),
- a public store typealias
  (`public typealias ReaderLibraryStore = Store<ReaderLibraryMachine.State, ReaderLibraryMachine.Event>`),
- a public `View` that receives an already wired store.

The governing rule is: **the component that owns a screen's identity retains
its Store**. Store lifetime must follow that identity, not whichever SwiftUI
closure happens to render the destination:

| Screen kind | Identity owner | Store owner | Constructed | Released |
|---|---|---|---|---|
| Fixed application/navigation root | Stable SwiftUI root identity | `RootStoreScreen`'s private lifetime owner | First evaluation for that root identity | Root leaves the hierarchy |
| Pushed destination | Coordinator path element | `RouteIdentifier` payload | When the coordinator appends the route | When the route is evicted from `path` |
| Coordinator-owned modal | Coordinator modal enum/payload | Modal payload | When the coordinator presents it | When the modal is cleared |
| Preview or test | Explicit preview/test scope | Local `Store` or `TestStore` variable | Inside the dependency override scope | Scope ends |

### Fixed roots: `RootStoreScreen`

The composition root uses `RootStoreScreen` only for a fixed SwiftUI root whose
identity is stable (`Projects/OratioApp/Sources/Navigation/RootStoreScreen.swift`):

```swift
RootStoreScreen(
    initial: ReaderLibraryMachine.State.initial,
    machine: ReaderLibraryMachine(navigation: libraryNavigation)
) { store in
    ReaderLibraryView(store: store)
}
```

`RootStoreScreen` defers `Store.init` through its private
`ViewLifetimeStoreOwner` held by `@StateObject`. A constructed store immediately
bootstraps its feedback loop, so an eagerly built and discarded root store would
perform real work. This helper is intentionally root-only; it is not a general
Store ownership abstraction and must not be used for pushed destinations or
coordinator-owned modals. It remains outside `OratioUI`: DesignSystem must stay
free of state-management libraries (gnosis `dxamww`).

### Routes and coordinator-owned modals

The coordinator constructs a destination Store exactly once, as it appends the
route, and the route payload retains that Store for the full stack lifetime:

```swift
func showVoiceExperienceDetail(_ experience: VoiceExperience) {
    let navigation = VoiceExperienceDetailNavigation(
        showPaywall: { [weak self] in self?.showPaywall(source: .voiceDetail) }
    )
    let store = VoiceExperienceDetailStore(
        initial: VoiceExperienceDetailMachine.State(experience: experience),
        machine: VoiceExperienceDetailMachine(navigation: navigation)
    )
    path.append(.voiceExperienceDetail(
        RouteIdentifier(value: store, id: { _ in experience.id })
    ))
}

// Destination rendering never constructs or wraps another Store.
case let .voiceExperienceDetail(route):
    VoiceExperienceDetailView(store: route.value)
```

The navigation closure retained by a Store must capture its coordinator weakly.
Otherwise `coordinator -> path -> route -> Store -> machine/navigation ->
coordinator` forms a cycle and popping the route cannot release the Store. A
covered route remains in `path`, so its Store and long-lived observations remain
alive while another destination is pushed over it. Evicting the route releases
the Store and cancels its route-lifetime feedbacks. The same rule applies to a
coordinator-owned modal: store the modal's Store in its payload and render that
payload directly; do not construct it in `.sheet(item:)` or
`.fullScreenCover(item:)` closures.

### Preview and test ownership

Previews and tests construct real `Store`/`TestStore` values explicitly inside
the `withDependencies` scope that supplies every machine dependency. Pass the
retained Store to the feature View and seed an explicit initial state for each
meaningful preview, including loading and failure states. Every SwiftUI preview
uses `.withFonts()`. Preview/test scopes do not use `RootStoreScreen`, resolve
live services from a View, or construct a Store inside a View initializer/body.

`RootStoreScreen` is the selected narrow-root option. A specialized root holder
without a generic wrapper and documentation-only retention were considered and
rejected: the former duplicates safe lazy-root boilerplate, while the latter
leaves a universal `StoreScreen`-style API that advertises the wrong ownership
model. Keep root, route, modal, preview, and test ownership explicit instead.

Tuist wiring (`Tuist/ProjectDescriptionHelpers/Projects/`):

- `FeaturesModuleName.swift` — the Reader and Voice Experience feature targets
  depend on `.external(.CombineFeedback)`; their test targets depend on
  `.external(.CombineFeedbackTest)`.
- `AppModuleName.swift` — OratioApp depends on `.external(.CombineFeedback)`
  for `RootStoreScreen` and route construction.

When adopting CombineFeedback in another feature, mirror the Reader case in
`FeaturesModuleName.swift` and run `mise exec -- tuist generate`.

## Child Machine Composition

Compose children with `Scope` inside the parent's body, one parent `Event`
case per child:

```swift
Scope(state: \.documentImport, event: \.documentImport) {
    DocumentImportMachine(showPaywall: navigation.showPaywall)
}
```

**Reducer ordering trap.** Every reducer in the body sees every event, in
declaration order. A parent reducer that must read **pre-child** state must be
declared *before* the `Scope`. `ReaderLibraryMachine` declares its reducer
first, then the `Scope`s, and carries a comment explaining why: if `Scope` ran
first, the child would reset its flow before the parent handled
`.documentImport(.importFinished(.success))`, silently dropping the imported
document. The regression test
`importFinishedPrependsDocumentWhileChildFlowIsIdle` in
`ReaderLibraryMachineTests` protects this. Keep both the comment and the test
when refactoring.

**No delegate channel.** Reducers cannot emit events, so a child has no way to
send output events to its parent (gnosis `kabaxn`). The parent matches the
child event it consumes directly (`case let
.documentImport(.importFinished(.success(document)))`), and the child marks
such cases under a `// MARK: - Output` heading in its `Event` enum
(`DocumentImportMachine.Event.importFinished`) so a later editor can see which
cases are part of the contract. Do not invent a separate delegate event
vocabulary.

## The Request Idiom

The repo default for one-shot, cancellable side work: an optional request
value + `OnChange(of:)` + a completion event that nils it.

- Stored request: `ReaderLibraryMachine.DeletionRequest` — reducer sets
  `state.deletionRequest`, `deleteEffect` observes it, `.deleteSucceeded` /
  `.deleteFailed` clear it:

```swift
// Reducer
case let .deleteConfirmed(document):
    state.documents = .loaded(documents.filter { $0.id != document.id })
    state.deletionRequest = .init(documentID: document.id)

// Effect
private var deleteEffect: OnChange<State, Event, DeletionRequest> {
    OnChange(of: \.deletionRequest) { [readerLibraryUseCase] request in
        do {
            try await readerLibraryUseCase.delete(id: request.documentID)
            return .deleteSucceeded    // reducer sets deletionRequest = nil
        } catch {
            return .deleteFailed(error)
        }
    }
}
```
- Derived request: `DocumentImportMachine` derives `PreparingRequest` /
  `ImportRequest` from its `Flow` enum in a private extension — the enum owns
  the lifecycle, the projection exists only for `OnChange`.
- Empty-struct one-shot: `StarterBookOfferMachine.Request` is an empty struct
  derived from `isResolving`; `SuppressionRequest` carries just the id it
  needs.

Prefer deriving the request from an existing lifecycle enum over storing a
parallel optional, per the modeling skill. Work exists exactly while the
request is non-nil; leaving the state cancels it.

## OnStoreStart

`OnStoreStart` is the public upstream CombineFeedback primitive supplied by the
pinned package revision in `Tuist/Package.swift` (and recorded in
`Tuist/Package.resolved`). Use it directly inside a machine to subscribe to a
store-lifetime `AsyncSequence`, for example
`OnStoreStart { plusEntitlementUseCase.entitlementUpdates().map(Event.entitlementObserved) }`.
The sequence is subscribed once when that feedback is subscribed, and
cancellation tears it down with the Store. A finite sequence is
**silently one-shot**: completion does not restart it after later state updates;
a new subscription caused by optional/case-based `Scope` re-entry starts a new
sequence. Do not add or retain feature-local `OnStoreStart.swift` helpers or
duplicate this upstream primitive; machines consume the public CombineFeedback
API directly, while the assembly root only owns the Store lifetime.

### Stateful facade and initiating-caller configuration

`VoiceExperienceConfigurationUseCase` is a constructor-injected Domain facade
backed by one app-wide Store. `LiveDependencies.swift` retains one
`appVoiceExperienceConfiguration`, sharing the app installer and speech
preferences. Route owners still retain only their UI Stores. Follow the master
[DI reference](../app-architecture/references/dependency-injection.md) for split
keys and constructor assembly; this does not change the Feature initializer rule.

Every command is synchronous and returns `Void`; outcomes exist only as
engine-scoped state, and `updates(for:)` yields the current state first, then
each distinct update until the observer cancels:

```swift
private var observationEffect: some StateMachine<State, Event> {
    OnStoreStart { [configuration, engine] in
        configuration.updates(for: engine).map(Event.configurationObserved)
    }
}
```

`VoiceExperienceConfigurationState` carries the startup snapshot, the
eligibility the facade last revalidated for that engine (`nil` until then), and
the shared operations: every package's short dispatch slot, the single global
preference slot, and at most one failure fact for that engine. A route's
`State.selectionIntent` is local UI intent, not a waiter: it receives no
per-caller result, and a collision on the busy preference slot is rejected
without queueing. Domain holds no engine→package correlation
(`TTSModelInstalling` reports package-keyed state only), so a route resolves its
own package in `installStatuses` and applies its own version gate.

`VoiceExperienceConfigurationInteractionMachine.commandEffect` uses
`SideEffect(synchronous:)` to forward bounded, nonblocking facade commands in
Store event order. It reads post-reduction state, so a tap the route did not
accept forwards nothing; it waits for no installer call and retains no
second local package-operation lifecycle. Evicting the route cancels its
observation only — accepted app-wide work and installer-owned downloads
continue.

**Selecting an engine is a preference, never a paywall.** The configuration
policy and the facade take no entitlement provider at all, so a free user can
select any installed engine; access is decided per document at playback time by
`PremiumAccessPolicy` (a free user evaluates premium engines through an installed
Starter Book, and other documents fall back to Apple speech). `VoiceExperienceDetailMachine`
therefore navigates to the paywall **only** from its explicit Plus entry
(`.plusTapped`): it retains a pending paywall while hidden, and
`visiblePaywallRequest` becomes nonnil only after `.appeared`. The MainActor
critical section checks cancellation, stops the shared sample, then invokes the
weak coordinator closure. Lifecycle sample-stop commands remain unconditional.
Shared failures render inline through a route-local acknowledgment
(`ConfigurationMessage` plus `.messageDismissed`): shared state alone never
alerts or navigates, and clearing the shared fact re-arms the presentation for a
later attempt.

Compiled proof lives in `VoiceExperienceConfigurationUseCaseTests` (engine-scoped
current-first lenses, queue-free busy rejection, the eligibility/version table
with no entitlement dimension, removal ordering, bounded stale-fact reset),
`VoiceExperienceConfigurationInteractionMachineTests`
(two retained Detail Stores, local intent, synchronous command order, shared
failures rendered inline without navigation, route pop canceling observation
only), `VoiceExperienceDetailMachineTests` (shared audio command ordering,
paywall presented only from the Plus entry), and `VoiceExperienceDetailRouteStoreTests`
(route ownership and all three `voiceDetail` paywall sources). Use the colocated
`ControlledVoiceExperienceConfigurationUseCase` for state injection and command
recording, and generated mocks for thin collaborators; follow the master
[unit-testing skill](../unit-testing/SKILL.md) rather than adding another harness.

## Machine Shape Conventions

Follow `ReaderLibraryMachine.swift` / `DocumentImportMachine.swift`:

- One `<Screen>Machine.swift` (or `<Concern>Machine.swift`) per machine, in
  the screen folder next to its view.
- `State: Equatable, Sendable` — Equatable enables whole-value test
  assertions. Provide a `static let initial` when callers construct the state
  (`ReaderLibraryMachine.State.initial`, `DocumentImportMachine.State.initial`);
  a child state built inline by its parent may omit it
  (`StarterBookOfferMachine.State`).
- `@CasePathable public enum Event` mixing user intent (`.importTapped`),
  external input (`.entitlementObserved`), effect results
  (`.documentsLoaded(Result<…>)`), and child cases (`.documentImport(…)`).
- `body` is a `@StateMachineBuilder` listing the reducer first, then each
  effect as a named private computed property (`deleteEffect`,
  `paywallEffect`), then `Scope`s. Named properties keep the body a readable
  table of contents.
- Reducer helpers that encode policy shared by several events are private
  methods taking `inout State` (`applyImportIntent`).

## View Binding

Views consume the store through the `@StoreBinding` property wrapper
(`ReaderLibraryView.swift`):

```swift
@StoreBinding<ReaderLibraryMachine.State, ReaderLibraryMachine.Event>
private var state: ReaderLibraryMachine.State

init(store: ReaderLibraryStore) { _state = StoreBinding(store) }
```

- Send events via `$state.send(.appeared)`.
- Child views receive plain render data and callbacks, never the store —
  consistent with the AGENTS.md child-`View`-structs rule.
- Presentation bindings (alerts, dialogs, `fileImporter`) are hand-rolled
  `Binding(get:set:)` over state, where `set(false)` sends the dismiss event
  (`deletionConfirmationBinding`, `alertBinding` in `ReaderLibraryView`).
- Previews build a **real** `Store` inside `withDependencies` with preview
  doubles, passing a hand-built `initial` state per preview (see
  `makePreviewStore` in `ReaderLibraryView.swift`). Machines run their
  feedbacks in previews; the doubles must tolerate that.

## Testing (repo-specific)

Use [machine testing](../combinefeedback-state-machine-testing/SKILL.md) for
`TestStore` and destination assertions, [unit-testing](../unit-testing/SKILL.md)
for Mockable, gated decorators/`SuspensionGate`, colocated `Mutex`-backed controls,
and preview placement, and [deterministic async tests](../deterministic-async-tests/SKILL.md)
for synchronization. Do not infer progress from sleep or yield budgets.

Oratio reference points (read alongside their production protocols):

- `ReaderLibraryMachineTests.swift`: private mechanical `withStore` wraps
  dependency overrides around `TestStore` construction, including scoped children.
  Tests define generated mock behavior in their bodies and assert whole states.
- `DocumentImportMachineTests.swift`: `GatedDocumentImportUseCase` and
  `GatedPlusEntitlementUseCase` wrap generated mocks; `SuspensionGate` proves the
  effect is parked before cancellation. A state wait is not a dependency-entry signal.
- `Projects/Domain/Tests/OratioDomainTests/ReaderLibraryUseCaseTests.swift`:
  mock callbacks record ordered cleanup in a checked-Sendable `Mutex` recorder.
  Use this when call counts alone cannot prove order, rather than replacing thin
  collaborators with hand-written protocol stubs.

## Complexity

Judge a reducer by **cognitive** complexity, not cyclomatic — a flat switch
over every event inflates the cyclomatic count without being hard to read
(gnosis `cxgvty`). Split when cognitive complexity grows well beyond 20, or
when one concern owns enough state to become its own machine. Precedent: the
`ReaderLibraryMachine` → `DocumentImportMachine` split took the parent reducer
from cognitive 20 to 9.
