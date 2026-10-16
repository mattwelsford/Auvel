import AuvelProtocol
import AuvelTransport
import Foundation
import UIKit

/// App state: paired Macs, discovery, the selected Mac's session and settings.
@MainActor
@Observable
final class AppModel {
    private(set) var pairedMacs: [StoredPairing] = []
    private(set) var discovered: [UUID: DiscoveredMac] = [:]
    private(set) var localNetworkDenied = false
    private(set) var session: RemoteSession?

    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Keys.onboarding) }
    }
    var hasSeenLocalNetworkExplainer: Bool {
        didSet { UserDefaults.standard.set(hasSeenLocalNetworkExplainer, forKey: Keys.explainer) }
    }

    @ObservationIgnored private let keychain = PairingKeychain(service: "nz.co.touchbase.auvel.pairing")
    @ObservationIgnored private let browser = BonjourBrowser(serviceType: Bonjour.serviceType)
    @ObservationIgnored let deviceID: UUID
    @ObservationIgnored let deviceName = UIDevice.current.name

    static let macDownloadURL = URL(string: "https://getauvel.com/mac")!
    static let sourceURL = URL(string: "https://github.com/mattwelsford/auvel")!

    private enum Keys {
        static let onboarding = "hasSeenOnboarding"
        static let explainer = "hasSeenLocalNetworkExplainer"
        static let selectedMac = "selectedMacID"
        static let deviceID = "deviceID"
    }

    init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: Keys.deviceID), let id = UUID(uuidString: stored) {
            deviceID = id
        } else {
            deviceID = UUID()
            defaults.set(deviceID.uuidString, forKey: Keys.deviceID)
        }
        hasSeenOnboarding = defaults.bool(forKey: Keys.onboarding)
        hasSeenLocalNetworkExplainer = defaults.bool(forKey: Keys.explainer)
        pairedMacs = (try? keychain.all()) ?? []

        browser.onChange = { [weak self] in
            guard let self else { return }
            discovered = browser.macs
            localNetworkDenied = browser.localNetworkDenied
            session?.endpointsChanged()
        }
        if !pairedMacs.isEmpty || hasSeenLocalNetworkExplainer { browser.start() }
        selectInitialMac()
    }

    // MARK: Discovery

    /// Starts Bonjour browsing. The first call triggers the iOS Local Network prompt (I02 comes first).
    func startBrowsing() {
        browser.start()
    }

    func restartBrowsing() {
        browser.restart()
    }

    func isPaired(_ mac: DiscoveredMac) -> Bool {
        pairedMacs.contains { $0.peerID == mac.id }
    }

    func isOnNetwork(_ pairing: StoredPairing) -> Bool {
        discovered[pairing.peerID] != nil
    }

    func makePairingFlow(for mac: DiscoveredMac) -> PairingFlow {
        PairingFlow(mac: mac, deviceID: deviceID, deviceName: deviceName) { [weak self] pairing in
            self?.save(pairing)
        }
    }

    // MARK: Paired Macs

    func select(_ pairing: StoredPairing) {
        guard session?.mac.peerID != pairing.peerID else { return }
        session?.deactivate()
        UserDefaults.standard.set(pairing.peerID.uuidString, forKey: Keys.selectedMac)
        let id = pairing.peerID
        session = RemoteSession(mac: pairing, deviceID: deviceID, deviceName: deviceName) { [weak self] in
            self?.discovered[id]?.endpoint
        }
        session?.activate()
    }

    func rename(_ pairing: StoredPairing, to name: String) {
        var renamed = pairing
        renamed.peerName = name
        try? keychain.save(renamed)
        pairedMacs = (try? keychain.all()) ?? []
    }

    func forget(_ pairing: StoredPairing) {
        try? keychain.remove(peerID: pairing.peerID)
        pairedMacs = (try? keychain.all()) ?? []
        if session?.mac.peerID == pairing.peerID {
            session?.deactivate()
            session = nil
            selectInitialMac()
        }
    }

    /// Stores a new pairing. The remote opens when the user taps Open Remote on I07.
    private func save(_ pairing: StoredPairing) {
        try? keychain.save(pairing)
        pairedMacs = (try? keychain.all()) ?? []
    }

    private func selectInitialMac() {
        let stored = UserDefaults.standard.string(forKey: Keys.selectedMac).flatMap(UUID.init(uuidString:))
        if let pairing = pairedMacs.first(where: { $0.peerID == stored }) ?? pairedMacs.last {
            select(pairing)
        }
    }

    // MARK: Foreground and background

    func didBecomeActive() {
        session?.activate()
    }

    func didEnterBackground() {
        session?.deactivate()
    }
}
