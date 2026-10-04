import AnnotateDomain
import ApplicationServices
import SwiftUI

/// The setup checklist shown when the app is opened directly.
struct SetupView: View {
    @State private var accessibilityAllowed = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Annotate for Agent").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Send a piece of Xcode code and a message to your coding agent through the clipboard.")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
            }
            VStack(spacing: 0) {
                ChecklistRow(step: 1, done: false, title: "Turn on the Xcode extension",
                             detail: "System Settings → General → Login Items & Extensions → Xcode Source Editor.")
                {
                    Button("Open…") { open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension") }
                }
                Divider().overlay(Palette.hairline)
                ChecklistRow(step: 2, done: accessibilityAllowed, title: "Allow Accessibility access",
                             detail: "Lets the app read which file is open in the front Xcode window.")
                {
                    Button("Allow…") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Divider().overlay(Palette.hairline)
                ChecklistRow(step: 3, done: false, title: "Pick a keyboard shortcut",
                             detail: "Xcode → Settings → Key Bindings → search “Copy Code with Message”.")
                {
                    EmptyView()
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT YOUR AGENT RECEIVES")
                    .font(.system(size: 11, weight: .semibold)).kerning(0.6).foregroundStyle(Palette.secondary)
                Text(Self.sample)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Palette.well, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Palette.surface)
        .task {
            // Accessibility access is granted in System Settings, so poll while the window is open.
            while !Task.isCancelled {
                accessibilityAllowed = AXIsProcessTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }

    private static let sample: String = {
        let selection = CodeSelection(
            range: SourceRange(SourcePosition(line: 25, column: 8), SourcePosition(line: 26, column: 0)),
            text: "let store = Store(initial: .idle, machine: session)\n"
        )
        let reference = CodeReference(file: URL(fileURLWithPath: "/Users/me/App/Sources/AppDelegate.swift"),
                                      selection: selection)
        guard let message = AnnotationMessage("Why is this created before launch?") else { return "" }
        return AgentPrompt.render(Annotation(reference: reference, message: message))
    }()
}

private struct ChecklistRow<Action: View>: View {
    let step: Int
    let done: Bool
    let title: String
    let detail: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(done ? Palette.ink : Palette.well)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.surface)
                } else {
                    Text("\(step)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.secondary)
                }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Group {
                if done {
                    Text("Done").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
                } else {
                    action
                }
            }
            .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    SetupView()
}
