import AuvelTransport
import SwiftUI

/// I05 code entry, I06 wrong code, I07 paired.
struct PairCodeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mac: DiscoveredMac

    @State private var flow: PairingFlow?
    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if case .paired(let pairing) = flow?.phase {
                paired(pairing)
            } else {
                entry
            }
        }
        .navigationTitle("Pair")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if flow == nil { flow = model.makePairingFlow(for: mac) }
            focused = true
        }
        .onDisappear { flow?.cancel() }
        .onChange(of: flow?.phase) { _, phase in
            switch phase {
            case .wrongCode, .failed, .macNotReady:
                Haptics.error()
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    code = ""
                    focused = true
                }
            case .paired:
                Haptics.success()
            default:
                break
            }
        }
    }

    // MARK: I05, I06

    private var entry: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: macSymbol(for: mac.model))
                    .font(.system(size: 44))
                    .foregroundStyle(Color.goldText)
                    .padding(.top, 26)
                    .accessibilityHidden(true)
                Text("Enter the code shown on\n\(mac.name)")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                Text("It's in the Auvel window on the Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack {
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(nil)
                        .focused($focused)
                        .opacity(0.02)
                        .accessibilityLabel("Pairing code, \(code.count) of 6 digits entered")
                        .onChange(of: code) { _, new in
                            let digits = String(new.filter(\.isNumber).prefix(6))
                            if digits != new { code = digits }
                            if digits.count == 6, flow?.phase == .enteringCode || isRetryable { flow?.submit(digits) }
                        }
                    CodeBoxes(code: code, error: isError)
                        .accessibilityHidden(true)
                        .onTapGesture { focused = true }
                }
                .padding(.top, 26)

                status
                    .padding(.top, 14)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var isRetryable: Bool {
        switch flow?.phase {
        case .wrongCode, .failed, .macNotReady: true
        default: false
        }
    }

    private var isError: Bool {
        if case .wrongCode = flow?.phase { return true }
        return false
    }

    @ViewBuilder
    private var status: some View {
        switch flow?.phase {
        case .working:
            HStack(spacing: 8) { ProgressView(); Text("Pairing…").foregroundStyle(.secondary) }
        case .wrongCode:
            Label("That code didn't match. Enter the new code shown on your Mac.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        case .macNotReady:
            Label("Open Pair an iPhone… in the Auvel menu on \(mac.name), then try again.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    // MARK: I07

    private func paired(_ pairing: StoredPairing) -> some View {
        let name = pairing.peerName
        return VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("Paired with\n\(name)")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Start a video in Safari on your Mac, then tap Play/Pause here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                model.select(pairing)
                dismiss()
            } label: {
                Text("Open Remote").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color(.label))
            .foregroundStyle(Color(.systemBackground))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
        .onAppear { UIAccessibility.post(notification: .announcement, argument: "Paired with \(name).") }
    }
}

private struct CodeBoxes: View {
    let code: String
    let error: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                if index == 3 { Spacer().frame(width: 10) }
                let digit = index < code.count ? String(Array(code)[index]) : ""
                Text(digit)
                    .font(.title.weight(.semibold).monospacedDigit())
                    .frame(width: 46, height: 58)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(error ? Color.red : (index == code.count ? Color.accentColor : .clear), lineWidth: 2)
                    }
            }
        }
    }
}
