import AnnotateFeature
import AppKit
import CombineFeedback
import SwiftUI

@main
struct XcodeAgentAnnotateApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // The capture flow lives as long as the app, so a new handoff can replace one in progress.
    private let store = Store(initial: CaptureSession.State.idle, machine: CaptureSession(dependencies: .live))
    private lazy var presenter = CapturePresenter(store: store) { [weak self] in
        self?.setupWindow?.orderOut(nil)
    }

    private var setupWindow: NSWindow?
    private var receivedCapture = false

    func applicationDidFinishLaunching(_: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Setup", action: #selector(showSetup), keyEquivalent: ",")
        appMenu.addItem(withTitle: "Quit Annotate for Agent", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        presenter.start()
        // LaunchServices also delivers URLs at startup; defer the setup window.
        DispatchQueue.main.async {
            if !self.receivedCapture { self.showSetupWindow(activate: false) }
        }
    }

    func application(_: NSApplication, open urls: [URL]) {
        receivedCapture = true
        presenter.start()
        for url in urls {
            store.send(event: .handoffReceived(url))
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        showSetup()
        return true
    }

    @objc private func showSetup() {
        showSetupWindow(activate: true)
    }

    private func showSetupWindow(activate: Bool) {
        if setupWindow == nil {
            let hosting = NSHostingController(rootView: SetupView())
            hosting.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.title = "Annotate for Agent — Setup"
            window.isReleasedWhenClosed = false
            window.center()
            setupWindow = window
        }
        if activate {
            NSApp.activate()
            setupWindow?.makeKeyAndOrderFront(nil)
        } else {
            setupWindow?.orderFront(nil)
        }
    }
}
