import AuvelProtocol
import AuvelSession
import AuvelTransport
import Foundation
import Network

/// A stand-in for Auvel for Mac (T5). Runs the real pairing and control protocol over real sockets,
/// with a fake audio device and media keys, so iPhone tests run without a Mac.
///
/// All mutable state lives on `queue`. Public methods are safe to call from any thread.
public final class MockMacServer: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var passkey: Passkey
        public var macID: UUID
        public var identity: MacIdentity
        /// Advertise over Bonjour, as the real Mac does. Off for tests that connect by port.
        public var advertise: Bool
        public var initialState: MacState

        public init(
            passkey: Passkey = Passkey(123_456)!,
            macID: UUID = UUID(uuidString: "0C2D9E1F-7A4B-4E3C-8B5A-1D2E3F4A5B6C")!,
            identity: MacIdentity = MacIdentity(name: "Mock Mac", model: "Mac15,3", appVersion: "1.0"),
            advertise: Bool = false,
            initialState: MacState = MacState(volume: 0.5, muted: false, volumeSettable: true,
                                              outputName: "Mock Speakers", mediaKeysAllowed: true)
        ) {
            self.passkey = passkey
            self.macID = macID
            self.identity = identity
            self.advertise = advertise
            self.initialState = initialState
        }
    }

    public let configuration: Configuration
    private let queue = DispatchQueue(label: "auvel.mock-mac")
    private var macState: MacState
    private var keys: [PreSharedKey] = []
    private var received: [ClientMessage] = []
    private var controlListener: NWListener?
    private var pairingListener: NWListener?
    private var sessions: [ObjectIdentifier: (FramedConnection<ClientFrame>, MacSessionLogicBox)] = [:]
    private var controlPortValue: NWEndpoint.Port?
    private var pairingPortValue: NWEndpoint.Port?

    public init(_ configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.macState = configuration.initialState
    }

    // MARK: Public API

    /// Starts both listeners and waits until they have ports.
    public func start() async throws {
        try await startPairing()
        try await startControl()
    }

    public func stop() {
        queue.sync {
            controlListener?.cancel()
            pairingListener?.cancel()
            controlListener = nil
            pairingListener = nil
            for (connection, _) in sessions.values { connection.cancel() }
            sessions.removeAll()
        }
    }

    /// Stops and restarts the control listener, dropping every connection. For reconnect tests (T3).
    public func restartControl() async throws {
        queue.sync {
            controlListener?.cancel()
            controlListener = nil
            for (connection, _) in sessions.values { connection.cancel() }
            sessions.removeAll()
        }
        try await startControl()
    }

    public var controlPort: NWEndpoint.Port? { queue.sync { controlPortValue } }
    public var pairingPort: NWEndpoint.Port? { queue.sync { pairingPortValue } }

    /// Every command, volume and mute message received, in order.
    public var receivedCommands: [ClientMessage] { queue.sync { received } }

    public var state: MacState { queue.sync { macState } }

    public var pairedDeviceIDs: [Data] { queue.sync { keys.map(\.identity) } }

    /// Changes the fake Mac's state as if the user did it on the Mac, and pushes it to connected iPhones.
    public func updateState(_ change: @Sendable (inout MacState) -> Void) {
        queue.sync {
            change(&macState)
            for (connection, box) in sessions.values where box.logic.isAuthenticated {
                connection.send(MacFrame(id: box.nextID(), message: .state(macState)))
            }
        }
    }

    // MARK: Listeners

    private func startControl() async throws {
        let parameters = queue.sync { TransportParameters.control(keys: keys) }
        let listener = try NWListener(using: parameters)
        if configuration.advertise {
            listener.service = NWListener.Service(
                name: configuration.identity.name, type: Bonjour.serviceType, domain: nil,
                txtRecord: NWTXTRecord([
                    Bonjour.TXTKey.protocolVersion: String(ProtocolVersion.current),
                    Bonjour.TXTKey.macID: configuration.macID.uuidString,
                    Bonjour.TXTKey.model: configuration.identity.model,
                ])
            )
        }
        listener.newConnectionHandler = { [weak self] connection in self?.acceptControl(connection) }
        let port = try await Self.waitForPort(listener, queue: queue)
        queue.sync {
            controlListener = listener
            controlPortValue = port
        }
    }

    private func startPairing() async throws {
        let listener = try NWListener(using: TransportParameters.pairing())
        if configuration.advertise {
            listener.service = NWListener.Service(
                name: configuration.identity.name, type: Bonjour.pairingServiceType, domain: nil,
                txtRecord: NWTXTRecord([Bonjour.TXTKey.macID: configuration.macID.uuidString])
            )
        }
        listener.newConnectionHandler = { [weak self] connection in self?.acceptPairing(connection) }
        let port = try await Self.waitForPort(listener, queue: queue)
        queue.sync {
            pairingListener = listener
            pairingPortValue = port
        }
    }

    private static func waitForPort(_ listener: NWListener, queue: DispatchQueue) async throws -> NWEndpoint.Port {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NWEndpoint.Port, Error>) in
            let once = Once()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if once.claim() { continuation.resume(returning: listener.port!) }
                case .failed(let error):
                    if once.claim() { continuation.resume(throwing: error) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    // MARK: Control sessions (on queue)

    private func acceptControl(_ nw: NWConnection) {
        let connection = FramedConnection<ClientFrame>(connection: nw)
        let box = MacSessionLogicBox()
        sessions[ObjectIdentifier(connection)] = (connection, box)
        connection.start()
        Task { [weak self] in
            for await event in connection.events {
                guard let self else { return }
                switch event {
                case .ready: break
                case .frame(let frame): self.queue.sync { self.handle(frame, connection: connection, box: box) }
                case .closed: self.queue.sync { self.sessions[ObjectIdentifier(connection)] = nil }
                }
            }
        }
    }

    private func handle(_ frame: ClientFrame, connection: FramedConnection<ClientFrame>, box: MacSessionLogicBox) {
        let actions = box.logic.handle(frame, identity: configuration.identity) { message in
            received.append(message)
            switch message {
            case .command:
                return macState.mediaKeysAllowed ? nil : .mediaKeysNotAllowed
            case .setVolume(let level):
                guard macState.volumeSettable else { return .volumeNotSettable }
                macState.volume = level
                if level > 0 { macState.muted = false }
                return nil
            case .setMuted(let muted):
                guard macState.volumeSettable else { return .volumeNotSettable }
                macState.muted = muted
                return nil
            default:
                return .badRequest
            }
        }
        for action in actions {
            switch action {
            case .send(let message): connection.send(MacFrame(id: box.nextID(), message: message))
            case .sendState, .sendStateNow: connection.send(MacFrame(id: box.nextID(), message: .state(macState)))
            case .sleepSoon: received.append(.sleep)
            case .close: connection.cancel()
            case .authenticated: break
            }
        }
    }

    // MARK: Pairing (on queue)

    private func acceptPairing(_ nw: NWConnection) {
        let connection = FramedConnection<PairFrame>(connection: nw)
        let configuration = configuration
        connection.start()
        Task { [weak self] in
            var machine = PairingServer(passkey: configuration.passkey, macID: configuration.macID, macName: configuration.identity.name)
            for await event in connection.events {
                guard let self, case .frame(let frame) = event else { continue }
                do {
                    let (send, result) = try machine.receive(frame)
                    for outgoing in send { connection.send(outgoing) }
                    if let result {
                        self.queue.sync {
                            self.keys.removeAll { $0.identity == PreSharedKey(deviceID: result.peerID, key: Data()).identity }
                            self.keys.append(PreSharedKey(deviceID: result.peerID, key: result.keyData))
                        }
                        try? await self.restartControl()
                    }
                } catch let error as PairingError {
                    if !error.fromPeer { connection.send(machine.failureFrame(error.reason)) }
                } catch {
                    connection.cancel()
                }
            }
        }
    }
}

/// Reference wrapper so a session's logic can be mutated from the queue.
final class MacSessionLogicBox: @unchecked Sendable {
    var logic = MacSessionLogic()
    private var id: UInt32 = 0

    func nextID() -> UInt32 {
        id &+= 1
        return id
    }
}

/// Lets a continuation be resumed once from a callback that may fire several times. Used only on one queue.
final class Once: @unchecked Sendable {
    private var done = false

    func claim() -> Bool {
        if done { return false }
        done = true
        return true
    }
}
