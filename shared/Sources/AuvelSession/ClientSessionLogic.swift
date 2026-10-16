import AuvelProtocol
import Foundation

/// iPhone side of one control connection (protocol §4, §5). No networking: frames in, state out.
/// The iPhone app's `RemoteSession` adds transport concerns (connecting, retries, unpaired detection).
public struct ClientSessionLogic {
    public enum Phase: Equatable, Sendable {
        case awaitingHelloAck
        case connected
        /// No common protocol version (I13). `macIsOlder` picks which app the user should update.
        case updateRequired(macIsOlder: Bool)
    }

    public enum Outcome: Equatable, Sendable {
        case none
        case becameConnected
        /// Stop using this connection.
        case close
    }

    public private(set) var phase: Phase = .awaitingHelloAck
    public private(set) var state: MacState?
    public private(set) var macModel = ""
    public private(set) var macVersion: Int?
    /// Last command error, cleared by the next `ok`.
    public private(set) var lastFailure: ErrorCode?
    private var helloID: UInt32 = 0

    public init() {}

    public var isConnected: Bool { phase == .connected }

    /// The first message on every connection. `id` is the frame id the caller will use.
    public mutating func hello(id: UInt32, deviceID: UUID, deviceName: String, appVersion: String) -> ClientMessage {
        helloID = id
        return .hello(Hello(versions: ProtocolVersion.supported, deviceID: deviceID, deviceName: deviceName, appVersion: appVersion))
    }

    public mutating func handle(_ frame: MacFrame) -> Outcome {
        switch frame.message {
        case .helloAck(let ack):
            guard phase == .awaitingHelloAck else { return .none }
            macModel = ack.model
            macVersion = ack.version
            phase = .connected
            return .becameConnected
        case .state(let newState):
            state = newState
            return .none
        case .ok:
            lastFailure = nil
            return .none
        case .failure(let replyTo, let failure):
            if replyTo == helloID, phase == .awaitingHelloAck, failure.code == .unsupportedVersion {
                // The Mac reports its lowest version. Above ours means this app is the older one.
                let macMinimum = failure.minimumVersion ?? 0
                phase = .updateRequired(macIsOlder: macMinimum <= ProtocolVersion.current)
                return .close
            }
            lastFailure = failure.code
            return .none
        case .pong:
            return .none
        }
    }

    // MARK: Optimistic updates while the user drags or taps

    public mutating func applyLocalVolume(_ level: Double) {
        let level = min(max(level, 0), 1)
        state?.volume = level
        if state?.muted == true, level > 0 { state?.muted = false }
    }

    public mutating func applyLocalMute(_ muted: Bool) {
        state?.muted = muted
    }
}
