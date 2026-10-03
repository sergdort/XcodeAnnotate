import ApplicationServices
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Annotate for Agent").font(.title)
            Text("Copy a source selection, its file path, and your message to the clipboard.")
            Text("1. Install this app in Applications and enable its Xcode Source Editor extension in System Settings → General → Login Items & Extensions.")
            Text("2. Allow Accessibility access so the app can read Xcode’s active file path.")
            Button("Request Accessibility Access") {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            }
            Text("3. In Xcode, select code (or place a caret) and choose Editor → Annotate for Agent → Copy Code with Message. Assign a shortcut in Xcode’s Key Bindings settings.")
            Text("Enter copies. Escape cancels. Source files are never changed.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
