import AnnotateHandoff
import AppKit
import SwiftUI

/// Explains why a capture could not be copied. Accessibility gets step-by-step guidance.
struct FailureView: View {
    let error: CaptureError
    let dismiss: () -> Void

    var body: some View {
        PanelCard(width: 520) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: error == .accessibilityRequired ? "lock.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(Palette.well, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(explanation).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                if error == .accessibilityRequired {
                    steps.padding(.horizontal, 20).padding(.bottom, 20)
                }
                Rectangle().fill(Palette.hairline).frame(height: 1)
                HStack(spacing: 16) {
                    Spacer()
                    if error == .accessibilityRequired {
                        KeyButton(title: "Close", key: "esc", action: dismiss).keyboardShortcut(.cancelAction)
                        KeyButton(title: "Open System Settings", key: "↩", prominent: true, action: openSettings)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        KeyButton(title: "Close", key: "↩", prominent: true, action: dismiss)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .onExitCommand(perform: dismiss)
    }

    private var title: String {
        error == .accessibilityRequired ? "Allow Accessibility access" : "Cannot copy code with message"
    }

    private var explanation: String {
        guard error == .accessibilityRequired else { return error.localizedDescription }
        return "Annotate for Agent reads which file is open in the front Xcode window. "
            + "It doesn't read other apps or change your code. Nothing was copied."
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "Open Privacy & Security → Accessibility")
            step(2, "Turn on Annotate for Agent")
            step(3, "Run Copy Code with Message in Xcode again")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.well, in: RoundedRectangle(cornerRadius: 10))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.secondary)
                .frame(width: 20, height: 20)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.hairline))
            Text(text).font(.system(size: 13)).foregroundStyle(Palette.ink)
        }
    }

    private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        dismiss()
    }
}
