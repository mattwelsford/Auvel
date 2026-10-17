import AuvelProtocol
import AuvelTransport
import Foundation
import Network

/// One pairing attempt with one Mac (I05 to I07): finds its pairing service, runs the exchange, stores the key.
@MainActor
@Observable
final class PairingFlow {
    enum Phase: Equatable {
        case enteringCode
        case working
        /// The code was wrong. The Mac now shows a new one (ADR-005).
        case wrongCode
        /// The Mac's pairing window is closed or busy.
        case macNotReady
        case failed(String)
        case paired(StoredPairing)
    }

    let mac: DiscoveredMac
    private(set) var phase: Phase = .enteringCode

    @ObservationIgnored private let deviceID: UUID
    @ObservationIgnored private let deviceName: String
    @ObservationIgnored private let pairingBrowser = BonjourBrowser(serviceType: Bonjour.pairingServiceType)
    @ObservationIgnored private var connection: FramedConnection<PairFrame>?
    @ObservationIgnored private var machine: PairingClient?
    @ObservationIgnored private let onPaired: (StoredPairing) -> Void

    init(mac: DiscoveredMac, deviceID: UUID, deviceName: String, onPaired: @escaping (StoredPairing) -> Void) {
        self.mac = mac
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.onPaired = onPaired
        pairingBrowser.start()
    }

    func cancel() {
        connection?.cancel()
        connection = nil
        pairingBrowser.stop()
    }

    /// Starts the exchange with a full 6-digit code.
    func submit(_ code: String) {
        guard let passkey = Passkey(string: code) else { return }
        phase = .working
        Task { await run(passkey) }
    }

    private func run(_ passkey: Passkey) async {
        // The pairing service appears only while the Mac's pairing window is open. Bonjour can take
        // several seconds to report it, so wait up to 10 s before telling the user the Mac is not ready.
        var endpoint = pairingBrowser.macs[mac.id]?.endpoint
        let deadline = ContinuousClock.now + .seconds(10)
        while endpoint == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(150))
            endpoint = pairingBrowser.macs[mac.id]?.endpoint
        }
        guard let endpoint else {
            phase = .macNotReady
            return
        }

        var machine = PairingClient(passkey: passkey, deviceID: deviceID, deviceName: deviceName)
        let first = machine.start()
        self.machine = machine
        let connection = FramedConnection<PairFrame>(to: endpoint, using: TransportParameters.pairing())
        self.connection = connection
        connection.start()

        for await event in connection.events {
            switch event {
            case .ready:
                connection.send(first)
            case .frame(let frame):
                guard var machine = self.machine else { return }
                do {
                    let (send, result) = try machine.receive(frame)
                    self.machine = machine
                    for outgoing in send { connection.send(outgoing) }
                    if let result {
                        let stored = StoredPairing(peerID: result.peerID, peerName: result.peerName, key: result.keyData)
                        onPaired(stored)
                        phase = .paired(stored)
                        finish()
                        return
                    }
                } catch {
                    if !error.fromPeer { connection.send(machine.failureFrame(error.reason)) }
                    self.machine = machine
                    phase = switch error.reason {
                    case .codeMismatch, .confirmationFailed: .wrongCode
                    case .busy: .macNotReady
                    case .unsupportedVersion: .failed("Update Auvel on this iPhone or on the Mac, then try again.")
                    case .protocolError: .failed("Something went wrong while pairing. Try again.")
                    }
                    finish()
                    return
                }
            case .closed:
                if phase == .working { phase = .failed("The connection to \(mac.name) was lost. Try again.") }
                return
            }
        }
    }

    /// Lets the peer read our last frame before closing.
    private func finish() {
        let old = connection
        connection = nil
        machine = nil
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            old?.cancel()
        }
    }

    func reset() {
        phase = .enteringCode
    }
}
