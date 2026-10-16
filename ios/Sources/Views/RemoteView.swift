import AuvelProtocol
import AuvelTransport
import SwiftUI

/// Main remote, Direction B (I08 to I13, I19). The dial and buttons never move; state banners sit between them (F11).
struct RemoteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(SettingKey.volumeStep) private var step = 0.05
    @AppStorage(SettingKey.keepAwake) private var keepAwake = false
    @State private var showingPicker = false
    @State private var showingSettings = false

    let session: RemoteSession

    var body: some View {
        GeometryReader { proxy in
            let large = typeSize.isAccessibilitySize
            let diameter = min(large ? 260 : 330, proxy.size.width - 72)
            VStack(spacing: 0) {
                header(large: large)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                volumeNumeral(large: large)
                    .padding(.top, large ? 8 : 26)

                Spacer(minLength: 8)

                DialView(
                    volume: state?.volume ?? 0,
                    muted: state?.muted ?? false,
                    volumeEnabled: session.isConnected && (state?.volumeSettable ?? false),
                    playEnabled: session.isConnected && (state?.mediaKeysAllowed ?? true),
                    diameter: diameter,
                    step: step,
                    onVolume: { session.setVolume($0) },
                    onPlayPause: {
                        Haptics.command()
                        session.press(.playPause)
                    }
                )

                Spacer(minLength: 8)

                StateBanner(session: session)
                    .padding(.horizontal, 20)
                    .frame(minHeight: large ? 0 : 96)

                buttonRow(large: large)
                    .padding(.horizontal, large ? 12 : 0)
                    .padding(.bottom, large ? 12 : 28)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .sheet(isPresented: $showingPicker) {
            MacPickerSheet().environment(model)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environment(model)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: keepAwake) { UIApplication.shared.isIdleTimerDisabled = keepAwake }
    }

    private var state: MacState? { session.state }

    // MARK: Header

    @ViewBuilder
    private func header(large: Bool) -> some View {
        let chip = Button { showingPicker = true } label: {
            HStack(spacing: 8) {
                Image(systemName: macSymbol(for: session.macModel))
                Text(session.mac.peerName)
                    .font(.headline)
                    .lineLimit(large ? 3 : 1)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.leading)
                if large { Spacer(minLength: 0) }
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .auvelSurface(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mac: \(session.mac.peerName)")
        .accessibilityHint("Double-tap to switch Mac.")

        let settings = Button { showingSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .auvelSurface(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")

        if large {
            VStack(alignment: .trailing, spacing: 8) {
                settings
                chip.frame(maxWidth: .infinity)
            }
        } else {
            HStack {
                chip
                Spacer()
                settings
            }
        }
    }

    // MARK: Numeral

    @ViewBuilder
    private func volumeNumeral(large: Bool) -> some View {
        let text: String = {
            guard session.isConnected, let state else { return "—" }
            if !state.volumeSettable { return "—" }
            if state.muted { return "Muted" }
            return "\(Int((state.volume * 100).rounded()))"
        }()
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: text == "Muted" ? 44 : 64, weight: .light).monospacedDigit())
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .contentTransition(.numericText())
            if !large {
                Text("VOLUME")
                    .font(.caption.weight(.semibold))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(session.isConnected ? 1 : 0.3)
        // The dial's value already says this (voiceover.md).
        .accessibilityHidden(true)
    }

    // MARK: Buttons

    @ViewBuilder
    private func buttonRow(large: Bool) -> some View {
        let muted = state?.muted ?? false
        let keys = session.isConnected && (state?.mediaKeysAllowed ?? true)
        let volume = session.isConnected && (state?.volumeSettable ?? false)
        HStack(spacing: large ? 0 : 28) {
            RoundButton(symbol: "backward.fill", label: "Previous", showLabel: large, enabled: keys,
                        accessibilityLabel: "Previous track") {
                Haptics.command()
                session.press(.previous)
            }
            if large { Spacer(minLength: 0) }
            RoundButton(symbol: muted ? "speaker.slash.fill" : "speaker.wave.2.fill", label: "Mute", showLabel: large,
                        enabled: volume, inverted: muted, accessibilityLabel: "Mute") {
                Haptics.mute()
                session.setMuted(!muted)
            }
            .accessibilityValue(muted ? "On" : "Off")
            .accessibilityAddTraits(.isToggle)
            if large { Spacer(minLength: 0) }
            RoundButton(symbol: "forward.fill", label: "Next", showLabel: large, enabled: keys,
                        accessibilityLabel: "Next track") {
                Haptics.command()
                session.press(.next)
            }
        }
    }
}

private struct RoundButton: View {
    let symbol: String
    let label: String
    let showLabel: Bool
    let enabled: Bool
    var inverted = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(inverted ? Color.canvas : Color(.label))
                    .frame(width: 72, height: 72)
                    .auvelSurface(Circle(), inverted: inverted)
                if showLabel {
                    Text(label).font(.body)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(accessibilityLabel)
    }
}
