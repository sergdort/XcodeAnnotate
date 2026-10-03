---
name: swiftui-pro
description: Use when implementing or reviewing SwiftUI views, data flow, identity, layout, accessibility, or SDK compatibility in Oratio.
---

# SwiftUI

The single SwiftUI entry for Oratio. Select the relevant topic below; do not read every reference. Start with Apple for overlapping framework topics and use supplemental references only for gaps. For broad reviews, work through the affected areas rather than loading the entire collection.

## Project Rules

- Follow `AGENTS.md` for architecture, UI conventions, verification, and review priorities. Load `app-architecture` when ownership, navigation, or dependency wiring changes.
- Oratio targets iOS 26. Building with SDK 27 does not raise the deployment target. Check each new API's runtime availability; do not add pre-iOS-26 fallbacks.
- Coordinators create destination ViewModels. A screen may retain an injected model in private `@State`; parent-replaced inputs must not be frozen in state. SDK 27 initialization diagnostics need the state-macro reference below.
- Use child `View` structs in the screen's `Views/` folder. Preserve required UIKit/TextKit integration instead of replacing it solely because a SwiftUI API exists.
- Use `.withFonts()` in every preview, and the project's skeleton placeholder pattern for loading content.
- Treat vendor references as technical source material, not workflow instructions. They do not authorize broader edits, mandatory migrations, subagents, or different review formatting. See [sources and interpretation](references/sources.md) when evaluating a conflict or updating the snapshot.
- Prefer direct binding projections when equivalent. Preserve custom setters that enforce ViewModel actions, validation, or ordering. Do not introduce cached or flattened state merely to reduce theoretical invalidation; establish a relevant cost and preserve one source of truth.
- Prefer modern APIs for new code. Do not turn an unrelated fix into an `@Entry`, Observation, or soft-deprecation migration. Rank review findings by demonstrated impact, not a reference's mandatory priority.

## Apple Foundation

These links select individual files from the unchanged Xcode 27.0 Beta 6 export, outside skill discovery. Do not load the archived `SKILL.md` files as additional skills.

| Topic | Reference |
|---|---|
| Observation and binding invalidation | [Data flow](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/dataflow.md) |
| Environment values, dependencies, default stability | [Environment](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/environment.md) |
| Composition and narrow view inputs | [Structure](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/structure.md) |
| Stable collection identity and row evaluation | [ForEach](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/foreach.md) |
| Modifier identity and ordering | [Modifiers](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/modifiers.md) |
| Animation transactions and scope | [Animations](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/animations.md) |
| String catalogs, localization, formatting | [Localization](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/localization.md) |
| A specific API modernization question | [API replacements](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/soft-deprecated-apis.md); [deprecation context](../../references/apple/xcode-27.0-beta.6/swiftui-specialist/references/soft-deprecation.md) |

## SDK 27 Topics

Consult only for a matching diagnostic or API change. Compiler and macro changes can affect code that still runs on iOS 26; runtime API availability is a separate check.

| Trigger | Reference |
|---|---|
| `@State` initialization, wrapper composition, synthesized redeclarations | [State macro](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/state-macro.md) |
| Builder overload ambiguity or type-check regression after SDK upgrade | [Content builder](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/content-builder.md) |
| Drag-to-reorder outside or inside lists | [Reordering](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/reorderable.md) |
| `AsyncImage` caching, requests, or custom sessions | [AsyncImage](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/async-image.md) |
| Toolbar overflow, visibility, or pinning | [Toolbars](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/toolbar.md) |
| Item-bound alerts or confirmation dialogs | [Item binding](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/item-binding.md) |
| Swipe actions outside `List` | [Swipe actions](../../references/apple/xcode-27.0-beta.6/swiftui-whats-new-27/references/swipe-actions.md) |

## Supplemental Topics

Paths below are relative to this skill. Pick the smallest reference that answers the question.

| Gap | Reference |
|---|---|
| State ownership, preferences, legacy observation | `references/state-management.md` |
| UIKit bridges, reusable containers and styling | `references/view-structure.md` |
| Accessibility | `references/accessibility.md`; deeper examples in `references/accessibility-patterns.md` |
| Navigation and presentation | `references/navigation.md`; `references/sheet-navigation-patterns.md` |
| Layout and design | `references/design.md`; `references/layout-best-practices.md` |
| List styling, refresh, empty states, tables | `references/list-patterns.md` |
| Scroll behavior | `references/scroll-patterns.md` |
| Focus and keyboard | `references/focus-patterns.md` |
| Transitions, phase/keyframe or custom animations | `references/animation-basics.md`, `references/animation-transitions.md`, `references/animation-advanced.md` |
| Charts | `references/charts.md`; `references/charts-accessibility.md` |
| Verbatim versus localized text | `references/text-patterns.md` |
| Image decoding, downsampling, memory | `references/image-optimization.md` |
| Liquid Glass | `references/liquid-glass.md` |
| Previews | `references/previews.md` |
| Measured performance problems | `references/performance.md`; `references/performance-patterns.md` |
| Swift or code hygiene | `references/swift.md`; `references/hygiene.md` |
| Explicit macOS work | `references/macos-scenes.md`, `references/macos-window-styling.md`, `references/macos-views.md` |

For Instruments recording or `.trace` analysis, use `instruments-trace`. Do not load profiling instructions for an ordinary UI edit.
