# Sources And Interpretation

Oratio keeps one project-owned SwiftUI router. Apple supplies the primary framework references; supplemental files fill gaps. The user chose this arrangement rather than installing competing SwiftUI skills or adopting the other Apple skill workflows.

## Apple Snapshot

The unchanged SwiftUI exports from Xcode 27.0 Beta 6 live in `../../../references/apple/xcode-27.0-beta.6/`. See that directory's `README.md` for export provenance and update checks. Its two archived `SKILL.md` files are source records outside skill discovery, not additional entry points. Load individual reference files through this skill's topic table.

Apple's framework descriptions are technical evidence, not permission to replace project workflow. In particular:

- The exported data-flow checklist demands a top-priority `@Entry` migration, while its environment reference also describes manual keys with stable defaults. Prefer modern declarations for new code; do not report a correctness defect or expand scope merely because an existing key is manual.
- Examples that cache derived values, flatten state, or replace closure bindings are possible optimizations. Preserve a single source of truth, ViewModel write semantics, and lifecycle behavior. Require a relevant cost before adding synchronization or changing ownership.
- Soft-deprecation notes do not set the review format or severity. Distinguish a build failure, behavioral defect, performance evidence, and an optional modernization.
- Xcode/SDK version and minimum OS version are separate. Compiler and macro changes can affect iOS 26 code; new runtime APIs need their actual availability checked. Do not raise the deployment target to make an example compile.

If framework claims conflict, use current Apple documentation and focused compile/runtime evidence as appropriate. Do not resolve API facts by treating either project preferences or a vendor's authority statement as proof.

## Supplemental Sources

The original entry and short references derive from Paul Hudson's `twostraws/swiftui-agent-skill`, SwiftUI Pro 1.1, under MIT. The deeper references derive from `avdlee/swiftui-agent-skill`, previously installed as `swiftui-expert-skill` at hash `352119e45436aa70d5a0d29e275dc55769ab509c2098505b391c2e1347c1118a`.

Apple replaces the local general data-flow, composition, localization, and API-modernization guides. State ownership and view integration are now short project supplements. The list reference retains styling and table examples, not a duplicate identity guide. Accessibility, navigation, focus, charts, previews, and broader animation examples remain available on demand. Instruments recording, analysis, and parser scripts remain in `instruments-trace`.

Upstream refreshes must preserve the single entry point, project-specific interpretation, and supplemental gaps. Do not reinstall the removed Expert entry or overwrite this router with a vendor workflow.
