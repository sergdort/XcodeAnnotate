# Annotate for Agent — Xcode prototype

A macOS companion app and Xcode Source Editor extension. Select code (or leave a
single caret to capture its current line), enter a message, and copy a reference
using the same clipboard format as
[annotate-for-agent-vs-code](https://github.com/sergdortXM/annotate-for-agent-vs-code).
The command never edits source files or selections.

## Build

Requires macOS 14+, Xcode, mise, and a development signing identity.
From this directory:

```sh
mise install
TUIST_ANNOTATE_DEVELOPMENT_TEAM=YOUR_TEAM_ID mise exec -- tuist generate --no-open
xcodebuildmcp macos build --workspace-path "$PWD/XcodeAgentAnnotate.xcworkspace" --scheme XcodeAgentAnnotate
xcodebuildmcp macos test --workspace-path "$PWD/XcodeAgentAnnotate.xcworkspace" --scheme XcodeAgentAnnotate --progress
```

Alternatively, generate without the environment variable, open the workspace,
select your development team for both app and extension, and build the
`XcodeAgentAnnotate` scheme. The manifest defaults to the author's personal team ID for this prototype; override it with `TUIST_ANNOTATE_DEVELOPMENT_TEAM` when generating.
If changing bundle IDs, keep the extension ID prefixed with the containing app ID.

Both app and extension explicitly use **Apple Development** signing. Do not
switch the extension to **Sign to Run Locally**: an ad-hoc signature can pass
`codesign --verify` but Xcode rejects it and omits the command from its Editor
menu. After building, check that the extension reports an Apple Development
authority and your team identifier:

```sh
codesign -dv --verbose=2 Build/Products/Debug/XcodeAgentAnnotate.app/Contents/PlugIns/AnnotateEditorExtension.appex
```

Tuist currently puts the app in `Build/Products/Debug/XcodeAgentAnnotate.app`.
The extension is embedded in `Contents/PlugIns`. Both targets are macOS targets;
the extension is sandboxed, while the companion is intentionally not sandboxed
because it reads Xcode through Accessibility.

The extension uses Xcode's source-editor startup library (`libXcodeExtension`)
and `_XCExtensionMain` entry point, matching the installed Xcode's native
source-editor target specification. Tuist's generic `.appExtension` startup is
not sufficient with this XcodeKit version: it logs a missing
`XCExtensionSubsystem` and leaves the Editor menu disabled. Building requires an
Xcode toolchain that supplies this startup library (verified with Xcode 27.1 beta).

The build scripts embed Xcode's own `XcodeKit.framework` and preserve its Apple
signature. The companion's post-build script restores framework headers removed
by Xcode's generated Copy App Extensions phase. Do not re-sign the framework.
Verify the final package with:

```sh
codesign --verify --deep --strict --verbose=2 Build/Products/Debug/XcodeAgentAnnotate.app
```

## Enable and use

1. Copy `Build/Products/Debug/XcodeAgentAnnotate.app` into `/Applications` (or your
   user Applications folder), then open it once. Use one installed copy to avoid
   LaunchServices resolving the URL scheme to an older build.
2. In System Settings, enable **Annotate for Agent** under **General → Login Items
   & Extensions → Xcode Source Editor**. On macOS 14, look under **Privacy &
   Security → Extensions** instead. Restart Xcode if the command does not appear.
3. In the app's setup window, click **Request Accessibility Access**, then enable
   the app in **Privacy & Security → Accessibility**. If macOS does not pick up
   the change, quit and reopen the app.
4. In Xcode, focus a saved local source file and select text or leave one caret.
   Use **Editor → Annotate for Agent → Copy Code with Message**.
5. Check the displayed file path, enter a nonblank message, and press Enter or
   click Copy. Escape, Cancel, and closing the panel leave the general clipboard
   unchanged. Focus returns to Xcode after the panel closes.

Assign a shortcut yourself in **Xcode → Settings → Key Bindings**. Xcode does not
let source extensions ship an automatic default shortcut.

## Implementation and limits

```text
XcodeKit command: capture selection/current line + buffer digest + Xcode PID
    → UUID-named pasteboard + token-only local launch URL
    → companion: verify focused AX editor, resolve AXDocument file URL
    → message panel: confirm → general clipboard; cancel → no clipboard write
```

- XcodeKit has no file-path API. Accessibility is required; the companion resolves
  the path before activating its panel. It requires the focused editor's text to
  match the captured buffer digest, then uses the nearest local document URL,
  falling back to the window's document.
- In split editors the window document can name the other pane's file; the
  copied code is always correct, but check the path there. Multiple Xcode processes are distinguished by PID; multiple-window
  behavior still needs live verification.
- Saved local files only. Unsaved *edits* are captured, but untitled files are not
  supported. No workspace search or disk-content fallback guesses a file path.
- Columns are interpreted as UTF-16 offsets. Unit cases cover emoji, combining
  marks, tabs, CRLF, and end-exclusive ranges; Xcode's actual Unicode/tab coordinate
  behavior still requires the live checks below.
- Source code is not put in the URL, logged, or deliberately written to disk.
  The temporary named pasteboard is not an encrypted/private IPC channel.
  Successful reads release it; unconsumed requests expire after 60 seconds and
  cleanup is best-effort if the extension process exits. The JSON payload limit
  is 16 MB. The general clipboard is only written after confirmation.
- No persistence, decorations, categories, sidebar, networking, or App Store
  distribution setup. Accessibility tree changes can cause safe rejection.

## Architecture

```text
AnnotateDomain   SourcePosition, SourceRange, CodeSelection, CodeReference,
                 AnnotationMessage, Annotation, AgentPrompt (clipboard format)
AnnotateHandoff  CaptureRequest, CaptureTransport, CaptureError   (+ Domain)
AnnotateFeature  CaptureSession state machine (CombineFeedback)   (+ Domain, Handoff)
EditorExtension  XcodeKit command → Domain + Handoff only
App              Store owner, live dependencies, AppKit presenter, SwiftUI views
```

`CaptureSession` owns the companion's lifecycle:

```text
idle ──handoffReceived──▶ resolving ──resolved──▶ composing ──submitted──▶ copying ──copied──▶ idle
                              │                      │  ▲                     │
                              └─failed─▶ failed      │  └────copyFailed───────┘
                                  │                  └──cancelled──▶ idle
                                  └─failureAcknowledged──▶ idle
```

A newer handoff always replaces the current one; a stale resolution is ignored.
Effects are state-owned: resolution runs while `resolving`, the clipboard write
runs while `copying`. Both are injected (`CaptureSession.Dependencies`), so the
machine is tested without Xcode, Accessibility, or the real clipboard.
`State.presentation` (hidden / composer / failure) is all the AppKit presenter
renders.

Future batch collection is meant to grow here: `Annotation` is already the
unit a collection would store, and the `submitted` transition is the single
place where "copy now" could become "add to collection".

CombineFeedback is integrated as an Xcode-native Swift package (pinned revision
in `Project.swift`, lockfile `.package.resolved`) rather than through
`Tuist/Package.swift`: Tuist's dependency graph reports a circular dependency
because `CombineFeedbackTest` references `IssueReporting` through the
`xctest-dynamic-overlay` shim, which re-exports a product with the same name
from `swift-issue-reporting`. Local modules are static libraries because Tuist
does not allow the app extension to depend on static frameworks.

## Verification

The automated suite protects selection extraction, exact clipboard bytes and
backtick fences, JavaScript-compatible message trimming, and single-use/expired
handoffs without changing the general clipboard, and the `CaptureSession`
transitions (copy once, refused write keeps the draft, failure acknowledgement,
cancel without copying, stale resolutions). It is not proof of live Xcode
extension loading, Accessibility structure, or keyboard behavior.

After enabling both permissions, use `Samples/SelectionFixture.swift` in Xcode:

- [ ] Select `greeting` on line 1: expect `1:5-1:13` and snippet `greeting`.
- [ ] With a caret anywhere on line 1: copy the entire line without its newline.
- [ ] Select text across lines; confirm exact whitespace and end-exclusive range.
- [ ] Change code without saving; confirm the preview reflects the unsaved edit.
- [ ] Select the emoji and combining-mark string; confirm the preview is not
      truncated and coordinates agree with Xcode's UTF-16 selection.
- [ ] Try a tab-indented line and a CRLF file, including a caret on an empty line.
- [ ] Select line 2; confirm the clipboard fence has five backticks.
- [ ] Start with a known clipboard value; cancel with Escape, Cancel, and the
      window close button. Paste afterward: the original value must remain.
- [ ] Submit only spaces: no copy. Enter a message and press Enter: one annotation.
- [ ] Invoke with the companion quit, then with it already running.
- [ ] Repeat with two Xcode windows/processes; verify the displayed path each time.
- [ ] Open split/comparison editors: check which file path is reported.
- [ ] Disable Accessibility or invoke on an untitled file: no clipboard change.
- [ ] Confirm source text and selection remain unchanged after every command.

See `THIRD_PARTY_NOTICES.md` for the original extension's license notice.
