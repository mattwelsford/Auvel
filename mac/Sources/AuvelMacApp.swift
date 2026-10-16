import AuvelProtocol
import SwiftUI

/// P2 skeleton: menu bar app with no features yet. P3 builds the M01–M06 designs.
@main
struct AuvelMacApp: App {
    var body: some Scene {
        MenuBarExtra("Auvel") {
            Text("Auvel · protocol v\(ProtocolVersion.current)")
            Divider()
            Button("Quit Auvel") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
