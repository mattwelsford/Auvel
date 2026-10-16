import AuvelProtocol
import SwiftUI

/// M05 and M06: shows the code, then the result. Closing the window withdraws the pairing service.
struct PairingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 8) {
            switch model.pairingPhase {
            case .showingCode(let code, let expires, let failures):
                Text("Enter this code in Auvel on your iPhone")
                    .font(.title3.weight(.semibold))
                Text("Choose “\(MacInfo.name)” in the list, then type the code.")
                    .foregroundStyle(.secondary)
                Text(code.description)
                    .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    .kerning(8)
                    .padding(.vertical, 18)
                    .accessibilityLabel(code.description.map { String($0) }.joined(separator: " "))
                    .textSelection(.enabled)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(expiryText(expires, now: context.date, failures: failures))
                        .font(.footnote)
                        .foregroundStyle(failures > 0 ? Color.orange : .secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Cancel") { dismissWindow(id: WindowID.pairing) }
                    .padding(.top, 12)

            case .paired(let name):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Paired with \(name)").font(.title3.weight(.semibold)).padding(.top, 8)
                Text("Auvel stays in the menu bar. You can close this window.").foregroundStyle(.secondary)
                Button("Done") { dismissWindow(id: WindowID.pairing) }
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 12)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        dismissWindow(id: WindowID.pairing)
                    }

            case .lockedOut:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Pairing stopped after 3 wrong codes").font(.title3.weight(.semibold)).padding(.top, 8)
                Text("Open Pair an iPhone… again to get a new code.").foregroundStyle(.secondary)
                Button("Try Again") { model.openPairing() }
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 12)

            case .closed:
                ProgressView()
            }
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .frame(width: 500)
        .onAppear {
            model.openPairing()
            bringToFront()
        }
        .onDisappear { model.closePairing() }
    }

    private func expiryText(_ expires: Date, now: Date, failures: Int) -> String {
        let remaining = max(0, Int(expires.timeIntervalSince(now)))
        let time = String(format: "%d:%02d", remaining / 60, remaining % 60)
        if failures > 0 {
            return "That code didn't match, so this is a new one. Expires in \(time)."
        }
        return "Expires in \(time). A new code is made each time this window opens."
    }
}
