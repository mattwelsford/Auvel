import AuvelProtocol
import AuvelTransport
import Foundation
import Network
import dnssd

/// Control service (protocol §5, §7): Bonjour-advertised TLS-PSK listener and one session per connected iPhone.
@MainActor
final class ControlServer {
    struct ConnectedPhone: Equatable, Identifiable {
        let id: UUID
        let name: String
    }

    /// Commands from iPhones. Return the failure to send back, or nil for `ok`.
    var execute: (ClientMessage) -> ErrorCode? = { _ in .internalError }
    var currentState: () -> MacState = { MacState(volume: 0, muted: false, volumeSettable: false, outputName: "", mediaKeysAllowed: false) }
    var onConnectedChange: ([ConnectedPhone]) -> Void = { _ in }
    var onLocalNetworkDenied: (Bool) -> Void = { _ in }

    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: Session] = [:]
    private static let maxConnections = 4

    /// (Re)starts the listener with the current set of paired keys. Called at launch and after pairing changes.
    func restart(keys: [PreSharedKey]) {
        listener?.cancel()
        for session in sessions.values { session.connection.cancel() }
        sessions.removeAll()
        publishConnected()

        do {
            let listener = try NWListener(using: TransportParameters.control(keys: keys))
            listener.service = NWListener.Service(
                name: nil,
                type: Bonjour.serviceType,
                domain: nil,
                txtRecord: NWTXTRecord([
                    Bonjour.TXTKey.protocolVersion: String(ProtocolVersion.current),
                    Bonjour.TXTKey.macID: MacInfo.id.uuidString,
                    Bonjour.TXTKey.model: MacInfo.model,
                ])
            )
            listener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated { self?.listenerChanged(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(connection) }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            NSLog("Auvel: control listener failed to start: \(error.localizedDescription)")
        }
    }

    /// Pushes the latest state to every iPhone that has completed `hello` (coalesced, §5.3).
    func broadcastState() {
        for session in sessions.values where session.isAuthenticated {
            session.sendState()
        }
    }

    private func listenerChanged(_ state: NWListener.State) {
        switch state {
        case .waiting(let error), .failed(let error):
            if case .dns(let code) = error, code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) {
                onLocalNetworkDenied(true)
            }
        case .ready:
            onLocalNetworkDenied(false)
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        // Unauthenticated connections are evicted first when the cap is reached (threat model T10).
        if sessions.count >= Self.maxConnections {
            guard let victim = sessions.values.first(where: { !$0.isAuthenticated }) else {
                connection.cancel()
                return
            }
            victim.connection.cancel()
        }
        let session = Session(connection: FramedConnection<ClientFrame>(connection: connection), server: self)
        sessions[ObjectIdentifier(session)] = session
        session.start()
    }

    fileprivate func ended(_ session: Session) {
        sessions[ObjectIdentifier(session)] = nil
        publishConnected()
    }

    fileprivate func publishConnected() {
        let phones = sessions.values.compactMap { s in s.phone.map { ConnectedPhone(id: $0.id, name: $0.name) } }
        onConnectedChange(phones.sorted { $0.name < $1.name })
    }

    // MARK: - Session

    @MainActor
    fileprivate final class Session {
        let connection: FramedConnection<ClientFrame>
        private unowned let server: ControlServer
        private(set) var phone: (id: UUID, name: String)?
        private var nextID: UInt32 = 1
        private var idleTimer: Timer?
        private var frameTimes: [Date] = []
        private var lastStateSent = Date.distantPast
        private var pendingState = false

        var isAuthenticated: Bool { phone != nil }

        init(connection: FramedConnection<ClientFrame>, server: ControlServer) {
            self.connection = connection
            self.server = server
        }

        func start() {
            connection.start()
            resetIdleTimer()
            Task { [weak self] in
                guard let events = self?.connection.events else { return }
                for await event in events {
                    guard let self else { return }
                    switch event {
                    case .ready: break
                    case .frame(let frame): self.handle(frame)
                    case .closed: self.end()
                    }
                }
            }
        }

        private func send(_ message: MacMessage) {
            connection.send(MacFrame(id: nextID, message: message))
            nextID &+= 1
        }

        /// At most one state push per 100 ms (protocol §5.3).
        func sendState() {
            let wait = 0.1 - Date().timeIntervalSince(lastStateSent)
            if wait <= 0 {
                lastStateSent = Date()
                send(.state(server.currentState()))
            } else if !pendingState {
                pendingState = true
                DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                    MainActor.assumeIsolated {
                        self?.pendingState = false
                        self?.sendState()
                    }
                }
            }
        }

        private func handle(_ frame: ClientFrame) {
            resetIdleTimer()
            let now = Date()
            frameTimes = frameTimes.filter { now.timeIntervalSince($0) < 1 } + [now]
            if frameTimes.count > 50 {
                send(.failure(replyTo: frame.id, Failure(code: .rateLimited)))
                connection.cancel()
                return
            }

            guard isAuthenticated else {
                guard case .hello(let hello) = frame.message else {
                    send(.failure(replyTo: frame.id, Failure(code: .badRequest)))
                    connection.cancel()
                    return
                }
                guard let version = ProtocolVersion.negotiate(client: hello.versions, server: ProtocolVersion.supported) else {
                    send(.failure(replyTo: frame.id, Failure(code: .unsupportedVersion, minimumVersion: ProtocolVersion.supported.first)))
                    connection.cancel()
                    return
                }
                phone = (hello.deviceID, hello.deviceName)
                send(.helloAck(HelloAck(version: version, macName: MacInfo.name, model: MacInfo.model, appVersion: MacInfo.appVersion)))
                sendState()
                server.publishConnected()
                return
            }

            switch frame.message {
            case .hello:
                send(.failure(replyTo: frame.id, Failure(code: .badRequest)))
            case .ping:
                send(.pong)
            case .getState:
                lastStateSent = .distantPast
                sendState()
            case .sleep:
                send(.ok(replyTo: frame.id))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { SystemSleep.sleepNow() }
            case .command, .setVolume, .setMuted:
                if let error = server.execute(frame.message) {
                    send(.failure(replyTo: frame.id, Failure(code: error)))
                } else {
                    send(.ok(replyTo: frame.id))
                }
            }
        }

        /// Closes the connection after 45 s without a frame (protocol §5.3).
        private func resetIdleTimer() {
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.connection.cancel() }
            }
        }

        private func end() {
            idleTimer?.invalidate()
            server.ended(self)
        }
    }
}
