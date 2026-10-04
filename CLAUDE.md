# Annotate for Agent — Xcode

An Xcode source editor extension and its macOS companion app. The user selects code
and runs **Copy Code with Message**. The companion asks for a message, then copies the
file path, range, code and message to the clipboard for a coding agent.

- The project lives in `XcodeAgentAnnotate/` and is generated with Tuist. See
  `XcodeAgentAnnotate/README.md` for build, test, architecture and limits.
- App logic uses CombineFeedback state machines (`Modules/AnnotateFeature`).
- Tests: `xcodebuildmcp macos test --workspace-path "$PWD/XcodeAgentAnnotate.xcworkspace" --scheme XcodeAgentAnnotate`
  (run from `XcodeAgentAnnotate/` after `mise exec -- tuist generate --no-open`).
