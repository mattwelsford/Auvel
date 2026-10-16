import SwiftUI

/// M01 and M02: a plain menu. Warning rows come first when something needs the user.
struct MenuContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.needsAttention ? "Auvel · Needs attention" : "Auvel · On")

        if model.needsAttention {
            Divider()
            if !model.accessibilityGranted {
                Button("Allow Media Key Control…", systemImage: "exclamationmark.triangle.fill") {
                    open(WindowID.welcome)
                }
            }
            if model.localNetworkDenied {
                Button("Allow Local Network Access…", systemImage: "exclamationmark.triangle.fill") {
                    Accessibility.openLocalNetworkSettings()
                }
            }
        }

        if !model.pairedPhones.isEmpty {
            Divider()
            Section("Paired iPhones") {
                ForEach(model.pairedPhones) { phone in
                    Text(model.isConnected(phone) ? "\(phone.peerName) · Connected" : phone.peerName)
                }
            }
        }

        Divider()
        Button("Pair an iPhone…") {
            model.openPairing()
            open(WindowID.pairing)
        }
        Button("Manage Paired iPhones…") { open(WindowID.manage) }
            .disabled(model.pairedPhones.isEmpty)

        Divider()
        Toggle("Open at Login", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
        Button("Check for Updates…") { model.updater.checkForUpdates() }
            .disabled(!model.updater.isAvailable)
        Button("About Auvel") {
            bringToFront()
            NSApp.orderFrontStandardAboutPanel(nil)
        }

        Divider()
        Button("Quit Auvel") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func open(_ id: String) {
        openWindow(id: id)
        bringToFront()
    }
}
