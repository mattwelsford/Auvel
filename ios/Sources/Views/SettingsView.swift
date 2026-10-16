import SwiftUI

/// I16 Settings and I18 Troubleshooting.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingKey.haptics) private var haptics = true
    @AppStorage(SettingKey.volumeStep) private var step = 0.05
    @AppStorage(SettingKey.keepAwake) private var keepAwake = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Haptics", isOn: $haptics)
                    Picker("Volume Step", selection: $step) {
                        Text("2%").tag(0.02)
                        Text("5%").tag(0.05)
                        Text("10%").tag(0.10)
                    }
                    Toggle("Keep Screen Awake", isOn: $keepAwake)
                } header: {
                    Text("Remote")
                } footer: {
                    Text("Keep Screen Awake stops the iPhone locking while the remote is open. Volume Step applies to VoiceOver adjustments.")
                }

                Section("Macs") {
                    LabeledContent("Paired Macs", value: "\(model.pairedMacs.count)")
                    ShareLink("Get Auvel for Mac", item: AppModel.macDownloadURL)
                    NavigationLink("Troubleshooting") { TroubleshootingView() }
                }

                Section("About") {
                    LabeledContent("Privacy", value: "Data Not Collected")
                    Link("Source Code", destination: AppModel.sourceURL)
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

struct TroubleshootingView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingForget = false

    var body: some View {
        List {
            Section("Mac not found") {
                Text("Auvel is running on the Mac. Look for its icon in the menu bar.")
                Text("iPhone and Mac are on the same Wi-Fi network.")
                Text("The Mac is awake. Auvel can't wake a sleeping Mac.")
                Text("VPNs and guest networks can block local devices.")
            }
            Section("Play/Pause does nothing") {
                Text("Accessibility is on for Auvel in System Settings on the Mac.")
                Text("The video or song was playing most recently. The Mac sends media keys to the app that last played.")
            }
            Section("Volume does nothing") {
                Text("Some displays and audio interfaces control their own volume. Auvel shows a notice when this happens.")
            }
            if let session = model.session {
                Section {
                    Button("Forget \(session.mac.peerName) and Pair Again", role: .destructive) {
                        confirmingForget = true
                    }
                }
                .confirmationDialog("Forget \(session.mac.peerName)?", isPresented: $confirmingForget, titleVisibility: .visible) {
                    Button("Forget", role: .destructive) { model.forget(session.mac) }
                }
            }
        }
        .font(.subheadline)
        .navigationTitle("Troubleshooting")
    }
}
