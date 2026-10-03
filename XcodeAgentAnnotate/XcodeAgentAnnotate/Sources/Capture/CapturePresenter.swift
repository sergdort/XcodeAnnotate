import AnnotateFeature
import AnnotateHandoff
import AppKit
import Combine
import CombineFeedback
import SwiftUI

/// Renders `CaptureSession.State.Presentation` with AppKit windows. Holds no flow state of its own.
@MainActor
final class CapturePresenter: NSObject, NSWindowDelegate {
    private let store: Store<CaptureSession.State, CaptureSession.Event>
    private let onComposerShown: () -> Void
    private var subscription: AnyCancellable?
    private var panel: NSPanel?
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
        switch presentation {
        case .hidden:
            closePanel()
            if case let .composer(sourceProcessID) = previous {
                NSRunningApplication(processIdentifier: sourceProcessID)?.activate(options: [])
            }
        case .composer:
            showPanel()
        case let .failure(error):
            closePanel()
            // Leave the publisher callback before running a modal loop.
            DispatchQueue.main.async { [store] in
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Cannot Copy Code with Message"
                alert.informativeText = error.localizedDescription
                alert.runModal()
                store.send(event: .failureAcknowledged)
            }
        }
    }

    private func showPanel() {
        if panel == nil {
            let panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 620, height: 420),
                                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.title = "Copy Code with Message"
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: ComposerView(store: store))
            panel.center()
            self.panel = panel
        }
        onComposerShown()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    private func closePanel() {
        panel?.orderOut(nil)
        // A fresh view per capture resets focus and scroll position.
        panel = nil
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        store.send(event: .cancelled)
        return false
    }
}
