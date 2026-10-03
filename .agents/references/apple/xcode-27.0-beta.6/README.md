# Apple SwiftUI Reference Snapshot

Exported on 2026-09-05 from `/Applications/Xcode-27.0.0-Beta.6.app` using `xcrun agent skills export <temporary-directory>`. Only `swiftui-specialist` and `swiftui-whats-new-27` are included. No other Apple skill is installed or routed from this snapshot.

The 18 exported Markdown files are unchanged: two source `SKILL.md` files and 16 topic references. Original text and attribution remain Apple's; the MIT license on the separate SwiftUI Pro package does not relicense these files.

The exported `swiftui-specialist/references/environment.md` contains trailing whitespace on 20 lines. It is retained for byte-for-byte provenance; whitespace diagnostics on those unchanged vendor lines are not local formatting regressions.

This directory is deliberately outside `.agents/skills/` and must not be registered as a skill discovery path. The archived entry files preserve provenance, not active instructions. Oratio's `../../../skills/swiftui-pro/SKILL.md` is the sole SwiftUI entry and selects individual topic references. Its project rules govern workflow and local interpretation.

## Updating

1. Export from the selected Xcode release into a temporary directory. Record the actual Xcode release; do not label beta content as final.
2. Compare the two SwiftUI exports, including file inventory and byte changes. Do not import unrelated Apple skills.
3. Review changed API claims, availability, and workflow instructions against the project's interpretation notes. Preserve useful supplemental coverage.
4. Add the reviewed snapshot under its Xcode version and update the router's topic links. Keep exported files unchanged rather than patching vendor text in place.
5. Validate reference paths, exported-file equality, and that only `swiftui-pro` is discoverable as the SwiftUI entry. Do not assume these structural checks prove future model behavior.
