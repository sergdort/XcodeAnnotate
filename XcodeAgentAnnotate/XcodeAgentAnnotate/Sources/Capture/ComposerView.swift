import AnnotateFeature
import CombineFeedback
import SwiftUI

struct ComposerView: View {
    @StoreBinding<CaptureSession.State, CaptureSession.Event> private var state: CaptureSession.State
    @FocusState private var messageFocused: Bool

    init(store: Store<CaptureSession.State, CaptureSession.Event>) {
        _state = StoreBinding(store)
    }

    var body: some View {
        if let draft = state.draft {
            content(draft)
        }
    }

    private func content(_ draft: ComposerDraft) -> some View {
        let selection = draft.capture.reference.selection
        return VStack(alignment: .leading, spacing: 12) {
            Text(draft.capture.reference.file.path).font(.callout).textSelection(.enabled)
            Text(selection.range.oneBasedDescription).font(.caption).foregroundStyle(.secondary)
            ScrollView([.horizontal, .vertical]) {
                Text(selection.text).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            TextField("Message for the agent", text: Binding(
                get: { draft.message },
                set: { $state.send(.messageChanged($0)) }
            ))
            .textFieldStyle(.roundedBorder)
            .focused($messageFocused)
            .onSubmit { $state.send(.submitted) }
            if let problem = draft.problem {
                Text(problem.localizedDescription).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("Check the file path before copying.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: $state.action(for: .cancelled)).keyboardShortcut(.cancelAction)
                Button("Copy", action: $state.action(for: .submitted)).keyboardShortcut(.defaultAction)
                    .disabled(draft.annotation == nil || state.isCopying)
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 340)
        .onAppear { messageFocused = true }
    }
}
