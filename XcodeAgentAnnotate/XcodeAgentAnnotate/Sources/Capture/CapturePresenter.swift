import AnnotateFeature
import AppKit
import Combine
import CombineFeedback
import SwiftUI

/// Renders `CaptureSession.State.Presentation` with floating panels. Holds no flow state of its own.
@MainActor
final class CapturePresenter {
    private let store: Store<CaptureSession.State, CaptureSession.Event>
    private let onComposerShown: () -> Void
    private var subscription: AnyCancellable?
    private var panel: FloatingPanel?
    private var shown = CaptureSession.State.Presentation.hidden

    init(store: Store<CaptureSession.State, CaptureSession.Event>, onComposerShown: @escaping () -> Void) {
        self.store = store
        self.onComposerShown = onComposerShown
    }

    func start() {
        guard subscription == nil else { return }
        // Async effects deliver state off the main thread.
        subscription = store.publisher
            .map(\.presentation)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presentation in
                MainActor.assumeIsolated { self?.render(presentation) }
            }
    }

    private func render(_ presentation: CaptureSession.State.Presentation) {
        let previous = shown
        shown = presentation
        // A fresh panel per presentation resets focus, scroll position and size.
        panel?.orderOut(nil)
        panel = nil
        switch presentation {
        case .hidden:
            returnFocus(after: previous)
        case .composer:
            onComposerShown()
            show(FloatingPanel(acceptsKey: true, content: ComposerView(store: store)))
        case let .confirmation(annotation):
            show(FloatingPanel(acceptsKey: false, content: ConfirmationView(annotation: annotation)))
            returnFocus(after: previous)
        case let .failure(error):
            show(FloatingPanel(acceptsKey: true, content: FailureView(error: error) { [store] in
                store.send(event: .failureAcknowledged)
            }))
        }
    }

    private func show(_ panel: FloatingPanel) {
        panel.placeOnActiveScreen()
        panel.orderFrontRegardless()
        if panel.canBecomeKey { panel.makeKey() }
        self.panel = panel
    }

    /// Hands focus back to the Xcode window the capture came from.
    private func returnFocus(after previous: CaptureSession.State.Presentation) {
        guard case let .composer(sourceProcessID) = previous else { return }
        NSRunningApplication(processIdentifier: sourceProcessID)?.activate()
    }
}
