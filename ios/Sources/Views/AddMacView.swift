import AuvelProtocol
import SwiftUI

/// I02 explainer, I03 searching, I04 results, I17 Local Network denied.
struct AddMacView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    let showsCancel: Bool

    var body: some View {
        Group {
            if !model.hasSeenLocalNetworkExplainer {
                explainer
            } else if model.localNetworkDenied {
                denied
            } else {
                list
            }
        }
        .navigationTitle(model.hasSeenLocalNetworkExplainer ? "Add a Mac" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Returning from Settings after allowing Local Network access.
            if phase == .active, model.localNetworkDenied { model.restartBrowsing() }
        }
    }

    // MARK: I02

    private var explainer: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.goldText)
                .frame(width: 84, height: 84)
                .background(.fill.tertiary, in: Circle())
                .accessibilityHidden(true)
            Text("Find your Mac on this network")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            Text("iOS will ask to let Auvel find devices on your local network. Auvel uses this only to reach your Mac. Nothing leaves your network.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Tap **Allow** on the next screen.")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.hasSeenLocalNetworkExplainer = true
                model.startBrowsing()
            } label: {
                Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color(.label))
            .foregroundStyle(Color(.systemBackground))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    // MARK: I17

    private var denied: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "network.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Auvel can't look for Macs").font(.title2.bold())
            Text("Local Network access is off for Auvel. Turn it on in Settings so Auvel can find your Mac.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            } label: {
                Text("Open Settings").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color(.label))
            .foregroundStyle(Color(.systemBackground))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    // MARK: I03, I04

    private var list: some View {
        let macs = model.discovered.values.sorted { $0.name < $1.name }
        return List {
            Section {
                ForEach(macs) { mac in
                    if model.isPaired(mac) {
                        Label { HStack { Text(mac.name); Spacer(); Text("Paired").foregroundStyle(.secondary) } }
                            icon: { Image(systemName: macSymbol(for: mac.model)).foregroundStyle(Color.goldText) }
                            .accessibilityLabel("\(mac.name), already paired")
                    } else {
                        NavigationLink(value: mac) {
                            Label(mac.name, systemImage: macSymbol(for: mac.model))
                        }
                    }
                }
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…").foregroundStyle(.secondary)
                }
            } header: {
                Text("Macs on this network")
            } footer: {
                Text("Only Macs running Auvel appear here.")
            }

            if macs.isEmpty {
                Section("Not listed?") {
                    Text("Open Auvel on the Mac. Its icon is in the menu bar.")
                    Text("Check both devices are on the same Wi-Fi network.")
                    Text("Guest and hotel Wi-Fi often block devices from seeing each other.")
                }
                .font(.subheadline)
                Section {
                    ShareLink("Send Yourself the Mac Link", item: AppModel.macDownloadURL)
                }
            }
        }
        .navigationDestination(for: DiscoveredMac.self) { mac in
            PairCodeView(mac: mac)
        }
        .onAppear { model.startBrowsing() }
    }
}
