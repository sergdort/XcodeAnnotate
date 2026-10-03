import AppKit
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var setupWindow: NSWindow?
    private var messagePanel: NSPanel?
    private var sourceApplication: NSRunningApplication?
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
        // LaunchServices also delivers URLs at startup; defer the setup window.
        DispatchQueue.main.async {
            if !self.receivedCapture { self.showSetupWindow(activate: false) }
        }
    }

    func application(_: NSApplication, open urls: [URL]) {
        receivedCapture = true
        for url in urls {
            do {
                let request = try CaptureTransport.consume(url)
                let file = try XcodeDocumentResolver.resolve(request)
                sourceApplication = NSRunningApplication(processIdentifier: request.xcodeProcessID)
                setupWindow?.orderOut(nil)
                present(request.capture, path: file.path)
            } catch {
                showError(error)
            }
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
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 520, height: 360),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Annotate for Agent — Setup"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ContentView())
            window.center()
            setupWindow = window
        }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            setupWindow?.makeKeyAndOrderFront(nil)
        } else {
            setupWindow?.orderFront(nil)
        }
    }

    private func present(_ capture: CodeCapture, path: String) {
        messagePanel?.orderOut(nil)
        let panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 620, height: 420),
                            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = "Copy Code with Message"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: MessageView(capture: capture, path: path) { message in
            if let message {
                let board = NSPasteboard.general
                board.clearContents()
                if !board.setString(capture.annotation(path: path, message: message), forType: .string) {
                    self.showError(CaptureError.clipboardWriteFailed)
                    return
                }
            }
            self.dismissPanel()
        })
        panel.center()
        messagePanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        dismissPanel()
        return false
    }

    private func dismissPanel() {
        messagePanel?.orderOut(nil)
        messagePanel = nil
        sourceApplication?.activate(options: [])
        sourceApplication = nil
    }

    private func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Cannot Copy Code with Message"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
