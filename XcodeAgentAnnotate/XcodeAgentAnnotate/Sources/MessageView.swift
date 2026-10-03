import SwiftUI

struct MessageView: View {
    let capture: CodeCapture
    let path: String
    let finish: (String?) -> Void
    @State private var message = ""
    @FocusState private var messageFocused: Bool

    private var trimmedMessage: String {
        CodeCapture.trimMessage(message)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(path).font(.callout).textSelection(.enabled)
            Text(capture.selectionDescription).font(.caption).foregroundStyle(.secondary)
            ScrollView([.horizontal, .vertical]) {
                Text(capture.snippet).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            TextField("Message for the agent", text: $message)
                .textFieldStyle(.roundedBorder)
                .focused($messageFocused)
                .onSubmit { copy() }
            HStack {
                Text("Check the file path before copying.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { finish(nil) }.keyboardShortcut(.cancelAction)
                Button("Copy") { copy() }.keyboardShortcut(.defaultAction)
                    .disabled(trimmedMessage.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 340)
        .onAppear { messageFocused = true }
    }

    private func copy() {
        guard !trimmedMessage.isEmpty else { return }
        finish(trimmedMessage)
    }
}
