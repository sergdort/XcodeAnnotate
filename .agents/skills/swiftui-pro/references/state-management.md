# State Ownership And Integration

For Observation dependency granularity, environment defaults, and binding invalidation, use the Apple references selected by `../SKILL.md`. This supplement covers ownership and project integration, not a second data-flow checklist.

## Choose Storage By Ownership

| Contract | Storage |
|---|---|
| View-local state retained for this view identity | Private `@State` |
| Coordinator-created model intentionally retained by the destination | Private `@State`, initialized from the injected model |
| Parent supplies a read-only value that can change | Ordinary stored property |
| Child writes parent-owned state | `@Binding` |
| View needs binding projections into an externally owned `@Observable` model | `@Bindable` |
| View only reads an externally owned observable model | Ordinary stored reference; body reads establish Observation dependencies |

`let` versus `var` on a plain input is a mutability choice, not a subscription mechanism. Replacing a parent input and retaining initial state are different contracts. Do not move an input into state merely to cache it.

In Oratio, coordinator creation and screen retention are compatible. The coordinator owns destination identity and constructs the ViewModel once. See `../../app-architecture/references/navigation.md` and `../../app-architecture/references/view-models.md` when changing that contract. For SDK 27 initialization failures, consult Apple's state-macro reference before changing initializer order or storage syntax.

## Preferences And Observation

`@ObservationIgnored` suppresses the Observation macro's treatment of a property. It does not make a wrapped preference observable or prove view invalidation. Oratio uses its preferences store and observable presentation state; do not introduce `@AppStorage` inside a ViewModel as a substitute for that flow.

When a binding write must call a ViewModel action, preserve the action's validation and ordering. A direct projected binding is preferable only when it has the same semantics. Moving writes into `onChange` can change that contract.

## Existing ObservableObject Integration

For legacy code, `@StateObject` retains an owned `ObservableObject`; `@ObservedObject` observes an externally owned one. Creating a model inline in `@ObservedObject` can recreate it as the parent updates. A parent object's publisher does not automatically forward a nested object's changes.

Use `@Observable` for new Oratio ViewModels, with the project's actor isolation and dependency rules. Do not migrate unrelated legacy code solely because the file is touched. Preserve cancellation, navigation identity, and update behavior in any deliberate migration.
