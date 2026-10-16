import AuvelTransport
import SwiftUI

/// I14 Mac picker and I15 sleep confirmation. Sleep lives here, not on the remote (W-D2).
struct MacPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSleep = false
    @State private var renaming: StoredPairing?
    @State private var newName = ""
    @State private var addingMac = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.pairedMacs) { mac in
                        Button {
                            model.select(mac)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "laptopcomputer")
                                    .foregroundStyle(model.isOnNetwork(mac) ? Color.goldText : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mac.peerName).foregroundStyle(Color(.label))
                                    Text(statusText(mac)).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.session?.mac.peerID == mac.peerID {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .accessibilityLabel("\(mac.peerName), \(statusText(mac))")
                        .accessibilityAddTraits(model.session?.mac.peerID == mac.peerID ? .isSelected : [])
                        .swipeActions {
                            Button("Remove", role: .destructive) { model.forget(mac) }
                            Button("Rename") {
                                newName = mac.peerName
                                renaming = mac
                            }
                            .tint(.gray)
                        }
                    }
                }

                Section {
                    Button("Add a Mac…") { addingMac = true }
                }

                if let session = model.session, session.isConnected {
                    Section {
                        Button {
                            confirmingSleep = true
                        } label: {
                            Label("Sleep \(session.mac.peerName)", systemImage: "moon.fill")
                                .foregroundStyle(Color(.label))
                        }
                        .accessibilityHint("Asks to confirm.")
                    } footer: {
                        Text("Swipe a Mac to rename or remove it.")
                    }
                }
            }
            .navigationTitle("Macs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(sleepTitle, isPresented: $confirmingSleep, titleVisibility: .visible) {
                Button("Sleep", role: .destructive) {
                    model.session?.sleepMac()
                    dismiss()
                }
            } message: {
                Text("Auvel can't wake it again. Use the Mac's keyboard or power button.")
            }
            .alert("Rename Mac", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Save") {
                    if let renaming, !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                        model.rename(renaming, to: newName)
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .sheet(isPresented: $addingMac) {
                NavigationStack { AddMacView(showsCancel: true) }
                    .environment(model)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sleepTitle: String {
        "Sleep \(model.session?.mac.peerName ?? "Mac")?"
    }

    private func statusText(_ mac: StoredPairing) -> String {
        if model.session?.mac.peerID == mac.peerID, model.session?.isConnected == true { return "Connected" }
        return model.isOnNetwork(mac) ? "Available" : "Not on this network"
    }
}
