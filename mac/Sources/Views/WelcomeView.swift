import SwiftUI

/// M03 and M04: Accessibility onboarding. Advances by itself when permission is granted.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.accessibilityGranted ? "Media key control is on" : "Allow Auvel to press media keys")
                        .font(.title3.weight(.semibold))
                    Text(model.accessibilityGranted
                         ? "Next, pair your iPhone."
                         : "macOS asks you to approve this once. Auvel uses it only for Play/Pause, Next and Previous.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if model.accessibilityGranted {
                Step(number: nil, text: "Accessibility allowed")
                Step(number: 2, text: "macOS may ask to let Auvel find devices on your local network. Click **Allow** so your iPhone can reach this Mac.")
                HStack {
                    Spacer()
                    Button("Pair iPhone") {
                        dismissWindow(id: WindowID.welcome)
                        model.openPairing()
                        openWindow(id: WindowID.pairing)
                        bringToFront()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Step(number: 1, text: "Click **Open System Settings**.")
                Step(number: 2, text: "Turn on **Auvel** in Privacy & Security › Accessibility. You may need your Mac password.")
                Step(number: 3, text: "Come back. This window updates by itself.")
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for permission…").foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("Volume and mute work without this.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Later") {
                        dismissWindow(id: WindowID.welcome)
                        model.openPairing()
                        openWindow(id: WindowID.pairing)
                        bringToFront()
                    }
                    Button("Open System Settings") { Accessibility.openSettings() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 500)
        .onAppear(perform: bringToFront)
    }
}

private struct Step: View {
    let number: Int?
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                if let number {
                    Text("\(number)").font(.caption.bold())
                        .frame(width: 20, height: 20)
                        .background(.quaternary, in: Circle())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 20, height: 20)
                }
            }
            .accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
