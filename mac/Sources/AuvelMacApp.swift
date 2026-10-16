import AppKit
import SwiftUI

@main
struct AuvelMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(model)
        } label: {
            Image(model.needsAttention ? "MenuBarIconAttention" : "MenuBarIcon")
                .accessibilityLabel(menuBarLabel)
        }
        .menuBarExtraStyle(.menu)

        Window("Welcome to Auvel", id: WindowID.welcome) {
            WelcomeView().environment(model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(AppModel.shouldShowWelcomeAtLaunch ? .presented : .suppressed)

        Window("Pair an iPhone", id: WindowID.pairing) {
            PairingView().environment(model)
        }
        .windowResizability(.contentSize)

        Window("Paired iPhones", id: WindowID.manage) {
            ManageView().environment(model)
        }
        .windowResizability(.contentSize)
    }

    private var menuBarLabel: String {
        if model.needsAttention { return "Auvel, needs attention" }
        let count = model.connected.count
        return count == 0 ? "Auvel" : "Auvel, \(count) iPhone\(count == 1 ? "" : "s") connected"
    }
}

enum WindowID {
    static let welcome = "welcome"
    static let pairing = "pairing"
    static let manage = "manage"
}

/// Menu bar apps have no Dock icon, so windows must bring the app forward explicitly.
@MainActor
func bringToFront() {
    NSApp.activate()
}
