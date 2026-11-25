import SwiftUI
import AppKit

@main
struct WalrusKeyboardMIDIApp: App {
    @StateObject private var engine = BoardEngine()

    var body: some Scene {
        Window("Walrus Keyboard MIDI", id: "main") {
            ContentView()
                .environmentObject(engine)
                .onAppear {
                    engine.start()
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Walrus Keyboard MIDI", systemImage: "keyboard") {
            MenuContent().environmentObject(engine)
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var engine: BoardEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Running", isOn: Binding(get: { engine.settings.enabled }, set: { engine.settings.enabled = $0 }))
        Button("Show Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Walrus Keyboard MIDI") { NSApp.terminate(nil) }
    }
}
