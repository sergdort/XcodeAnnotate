# View Integration And Styling

For view boundaries, narrow inputs, structural identity, and modifier behavior, use the Apple references selected by `../SKILL.md`. This supplement covers integration and reusable UI patterns.

## UIKit Bridges

Keep required UIKit/TextKit behavior. An available SwiftUI alternative is not proof of equivalent selection, layout, accessibility, or lifecycle behavior.

- Keep the representable struct's initializer cheap; SwiftUI can recreate the value repeatedly.
- Create the UIKit view in `makeUIView(context:)`. Creation is tied to the represented view's lifetime, not once for the entire app.
- Synchronize current render inputs in `updateUIView(_:context:)`. Do not assume an exact call count or perform unconditional expensive resets.
- Use the representable's `Coordinator` for delegate integration. Refresh callbacks or inputs that can change instead of retaining an obsolete copy of the representable.
- Avoid publishing synchronous state changes back into SwiftUI during its update pass. Preserve event ordering rather than adding arbitrary scheduling delays.
- Release observers, delegates, or resources in the appropriate dismantle/lifecycle path when required.

## Reusable Containers

When a container does not need deferred or repeated content construction, build and store the content value rather than retaining a closure solely for convenience:

```swift
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .background(.background, in: .rect(cornerRadius: 12))
    }
}
```

Do not change a deliberately deferred builder without checking when it reads state and how it is invoked.

## Styles And Layout

Use `ViewModifier` or a style protocol for shared treatments. Use `ButtonStyle` for appearance and `PrimitiveButtonStyle` only when custom interaction behavior is needed. Prefer existing Oratio design-system components over introducing parallel styles.

Use `overlay` or `background` for decoration anchored to a primary view. Use `ZStack` for peer views that jointly participate in layout. Preserve hit testing and accessibility when replacing conditional content with visual hiding; opacity alone is not an interaction policy.

Investigate compositing when layered clipping produces visible fringes. Do not add offscreen rendering to every clipped view without evidence.

For loading content, follow Oratio's `.skeletonPlaceholder()` pattern and pinned loading preview, not an ad hoc redaction-only implementation. For slow updates or type-checking diagnostics, start with the matching Apple topic; use `instruments-trace` only when profiling is needed.
