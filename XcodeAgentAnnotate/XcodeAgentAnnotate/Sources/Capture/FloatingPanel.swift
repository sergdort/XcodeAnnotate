import AppKit
import SwiftUI

/// A borderless, Spotlight-style panel that hosts SwiftUI content and sizes itself to it.
///
/// It never activates the app: since macOS 14 activation is cooperative and Xcode does not yield it,
/// so a key-capable non-activating panel is the only reliable way to take keyboard focus.
final class FloatingPanel: NSPanel {
    private let acceptsKey: Bool

    init(acceptsKey: Bool, content: some View) {
        self.acceptsKey = acceptsKey
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = acceptsKey
        ignoresMouseEvents = !acceptsKey
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let host = NSHostingController(rootView: content)
        host.sizingOptions = .preferredContentSize
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = .clear
        contentViewController = host
    }

    override var canBecomeKey: Bool {
        acceptsKey
    }

    override var canBecomeMain: Bool {
        acceptsKey
    }

    /// Places the panel horizontally centered, a little above the middle of the screen, like Spotlight.
    func placeOnActiveScreen(heightFraction: CGFloat = 0.72) {
        layoutIfNeeded()
        guard let screen = NSScreen.main?.visibleFrame else { return center() }
        let size = frame.size
        let origin = NSPoint(x: screen.midX - size.width / 2,
                             y: screen.minY + screen.height * heightFraction - size.height)
        setFrameOrigin(origin)
    }
}
