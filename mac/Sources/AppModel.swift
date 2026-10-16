import AuvelProtocol
import AuvelTransport
import Foundation
import Observation

/// App state and wiring between the services and the menu and windows.
@MainActor
@Observable
final class AppModel {
    private(set) var accessibilityGranted = Accessibility.isTrusted
    private(set) var localNetworkDenied = false
    private(set) var pairedPhones: [StoredPairing] = []
    private(set) var connected: [ControlServer.ConnectedPhone] = []
    private(set) var pairingPhase: PairingHost.Phase = .closed
    private(set) var openAtLogin = LoginItem.isEnabled
    @ObservationIgnored let updater = Updater()

    @ObservationIgnored private let audio = AudioController()
    @ObservationIgnored private let server = ControlServer()
    @ObservationIgnored private let pairing = PairingHost()
    @ObservationIgnored private let keychain = PairingKeychain(service: "nz.co.touchbase.auvel.mac.pairing")
    @ObservationIgnored private var pollTimer: Timer?

    var needsAttention: Bool { !accessibilityGranted || localNetworkDenied }

    /// First run, or Accessibility still missing: show the welcome window at launch (M03).
    static var shouldShowWelcomeAtLaunch: Bool {
        !Accessibility.isTrusted || ((try? PairingKeychain(service: "nz.co.touchbase.auvel.mac.pairing").all().isEmpty) ?? true)
    }

    init() {
        audio.onChange = { [weak self] _ in self?.server.broadcastState() }
        server.execute = { [weak self] message in self?.execute(message) ?? .internalError }
        server.currentState = { [weak self] in self?.macState ?? MacState(volume: 0, muted: false, volumeSettable: false, outputName: "", mediaKeysAllowed: false) }
        server.onConnectedChange = { [weak self] phones in self?.connected = phones }
        server.onLocalNetworkDenied = { [weak self] denied in self?.localNetworkDenied = denied }
        pairing.onChange = { [weak self] phase in self?.pairingPhase = phase }
        pairing.onPaired = { [weak self] result in self?.store(result) }

        Accessibility.registerWithSystem()
        LoginItem.enableOnFirstLaunch()
        openAtLogin = LoginItem.isEnabled
        audio.start()
        reloadPairings()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollAccessibility() }
        }
    }

    // MARK: Commands from iPhones

    private var macState: MacState {
        MacState(volume: audio.state.volume, muted: audio.state.muted, volumeSettable: audio.state.volumeSettable,
                 outputName: audio.state.outputName, mediaKeysAllowed: accessibilityGranted)
    }

    private func execute(_ message: ClientMessage) -> ErrorCode? {
        switch message {
        case .command(let command):
            let key: MediaKeys.Key = switch command {
            case .playPause: .playPause
            case .next: .next
            case .previous: .previous
            }
            return MediaKeys.press(key) ? nil : .mediaKeysNotAllowed
        case .setVolume(let level):
            return audio.setVolume(level) ? nil : .volumeNotSettable
        case .setMuted(let muted):
            return audio.setMuted(muted) ? nil : .volumeNotSettable
        default:
            return .badRequest
        }
    }

    private func pollAccessibility() {
        let trusted = Accessibility.isTrusted
        guard trusted != accessibilityGranted else { return }
        accessibilityGranted = trusted
        server.broadcastState()
    }

    // MARK: Pairing

    func openPairing() { pairing.open() }
    func closePairing() { pairing.close() }

    func isConnected(_ phone: StoredPairing) -> Bool {
        connected.contains { $0.id == phone.peerID }
    }

    func remove(_ phone: StoredPairing) {
        try? keychain.remove(peerID: phone.peerID)
        reloadPairings()
    }

    private func store(_ result: PairingResult) {
        do {
            try keychain.save(StoredPairing(peerID: result.peerID, peerName: result.peerName, key: result.keyData))
        } catch {
            NSLog("Auvel: could not save pairing: \(error)")
        }
        reloadPairings()
    }

    private func reloadPairings() {
        pairedPhones = (try? keychain.all()) ?? []
        server.restart(keys: pairedPhones.map { PreSharedKey(deviceID: $0.peerID, key: $0.key) })
    }

    // MARK: Settings

    func setOpenAtLogin(_ enabled: Bool) {
        LoginItem.setEnabled(enabled)
        openAtLogin = LoginItem.isEnabled
    }
}
