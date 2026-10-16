import AuvelProtocol
import AuvelTransport
import Foundation
import Network

/// Pairing window logic (protocol §6.2, M05, M06): advertises `_auvel-pair._tcp` only while open,
/// one session at a time, a new code after every failure, closes after 3 failures or 5 minutes.
@MainActor
final class PairingHost {
    enum Phase: Equatable {
        case closed
        case showingCode(Passkey, expires: Date, failures: Int)
        case paired(name: String)
        /// Closed after too many failed attempts. The user must reopen it.
        case lockedOut
    }

    private(set) var phase: Phase = .closed { didSet { onChange(phase) } }
    var onChange: (Phase) -> Void = { _ in }
    /// Called with the new pairing so the app can store it and restart the control listener.
    var onPaired: (PairingResult) -> Void = { _ in }

    private static let lifetime: TimeInterval = 5 * 60
    private static let maxFailures = 3

    private var listener: NWListener?
    private var session: FramedConnection<PairFrame>?
    private var machine: PairingServer?
    private var expiryTimer: Timer?
    /// A fixed code instead of a random one. Only set by the debug end-to-end test hook in AppModel.
    private var fixedPasskey: Passkey?

    func open(fixedPasskey: Passkey? = nil) {
        self.fixedPasskey = fixedPasskey
        guard listener == nil else { return }
        let listener: NWListener
        do {
            listener = try NWListener(using: TransportParameters.pairing())
        } catch {
            NSLog("Auvel: pairing listener failed: \(error.localizedDescription)")
            return
        }
        listener.service = NWListener.Service(
            name: nil, type: Bonjour.pairingServiceType, domain: nil,
            txtRecord: NWTXTRecord([Bonjour.TXTKey.macID: MacInfo.id.uuidString])
        )
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        listener.start(queue: .main)
        self.listener = listener
        newCode(failures: 0)
    }

    func close() {
        expiryTimer?.invalidate()
        session?.cancel()
        session = nil
        machine = nil
        listener?.cancel()
        listener = nil
        if case .showingCode = phase { phase = .closed }
    }

    private func newCode(failures: Int) {
        let expires = Date().addingTimeInterval(Self.lifetime)
        phase = .showingCode(fixedPasskey ?? .random(), expires: expires, failures: failures)
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: Self.lifetime, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func accept(_ connection: NWConnection) {
        guard case .showingCode(let passkey, _, _) = phase, session == nil else {
            // Busy: one session at a time (§6.2 rule 1).
            let busy = FramedConnection<PairFrame>(connection: connection)
            busy.start()
            busy.send(PairFrame(id: 1, message: .failed(PairFailed(reason: .busy))))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { busy.cancel() }
            return
        }
        let framed = FramedConnection<PairFrame>(connection: connection)
        session = framed
        machine = PairingServer(passkey: passkey, macID: MacInfo.id, macName: MacInfo.name)
        framed.start()
        Task { [weak self] in
            for await event in framed.events {
                guard let self else { return }
                switch event {
                case .ready: break
                case .frame(let frame): self.handle(frame, on: framed)
                case .closed: self.sessionEnded(framed)
                }
            }
        }
    }

    private func handle(_ frame: PairFrame, on connection: FramedConnection<PairFrame>) {
        guard connection === session, var machine else { return }
        do {
            let (send, result) = try machine.receive(frame)
            self.machine = machine
            for outgoing in send { connection.send(outgoing) }
            if let result {
                onPaired(result)
                finishSession()
                expiryTimer?.invalidate()
                listener?.cancel()
                listener = nil
                phase = .paired(name: result.peerName)
            }
        } catch {
            if !error.fromPeer { connection.send(machine.failureFrame(error.reason)) }
            self.machine = machine
            failed()
        }
    }

    private func sessionEnded(_ connection: FramedConnection<PairFrame>) {
        guard connection === session else { return }
        // A session that drops mid-exchange counts as a failure: bits may have leaked.
        if let machine, machine.state != .done, machine.state != .awaitingHello { failed() } else { finishSession() }
    }

    private func failed() {
        finishSession()
        guard case .showingCode(_, _, let failures) = phase else { return }
        if failures + 1 >= Self.maxFailures {
            close()
            phase = .lockedOut
        } else {
            newCode(failures: failures + 1)
        }
    }

    private func finishSession() {
        let old = session
        session = nil
        machine = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { old?.cancel() }
    }
}
