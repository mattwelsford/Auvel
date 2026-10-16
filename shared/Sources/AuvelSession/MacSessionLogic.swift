import AuvelProtocol
import Foundation

/// What the Mac tells iPhones about itself in `hello_ack`.
public struct MacIdentity: Equatable, Sendable {
    public var name: String
    public var model: String
    public var appVersion: String

    public init(name: String, model: String, appVersion: String) {
        self.name = name
        self.model = model
        self.appVersion = appVersion
    }
}

/// Mac side of one control connection (protocol §5). No networking: frames in, actions out.
/// The Mac app's `ControlServer` performs the actions. Contract tests drive this with the shared fixtures.
public struct MacSessionLogic {
    public enum Action: Equatable, Sendable {
        case send(MacMessage)
        /// Send the current state, subject to the 100 ms coalescing in §5.3.
        case sendState
        /// Send immediately, ignoring coalescing (reply to `get_state`).
        case sendStateNow
        /// The iPhone completed `hello`. Its identity is in `phone`.
        case authenticated
        /// Sleep the Mac shortly, after the `ok` has gone out.
        case sleepSoon
        case close
    }

    public static let maxFramesPerSecond = 50

    public private(set) var phone: (id: UUID, name: String)?
    private var frameTimes: [Date] = []

    public var isAuthenticated: Bool { phone != nil }

    public init() {}

    /// Handles one frame. `execute` performs media, volume and mute commands and returns the error to report, or nil.
    public mutating func handle(
        _ frame: ClientFrame,
        at now: Date = Date(),
        identity: MacIdentity,
        execute: (ClientMessage) -> ErrorCode?
    ) -> [Action] {
        frameTimes = frameTimes.filter { now.timeIntervalSince($0) < 1 } + [now]
        if frameTimes.count > Self.maxFramesPerSecond {
            return [.send(.failure(replyTo: frame.id, Failure(code: .rateLimited))), .close]
        }

        guard isAuthenticated else {
            guard case .hello(let hello) = frame.message else {
                return [.send(.failure(replyTo: frame.id, Failure(code: .badRequest))), .close]
            }
            guard let version = ProtocolVersion.negotiate(client: hello.versions, server: ProtocolVersion.supported) else {
                let failure = Failure(code: .unsupportedVersion, minimumVersion: ProtocolVersion.supported.first)
                return [.send(.failure(replyTo: frame.id, failure)), .close]
            }
            phone = (hello.deviceID, hello.deviceName)
            let ack = HelloAck(version: version, macName: identity.name, model: identity.model, appVersion: identity.appVersion)
            return [.send(.helloAck(ack)), .sendStateNow, .authenticated]
        }

        switch frame.message {
        case .hello:
            return [.send(.failure(replyTo: frame.id, Failure(code: .badRequest)))]
        case .ping:
            return [.send(.pong)]
        case .getState:
            return [.sendStateNow]
        case .sleep:
            return [.send(.ok(replyTo: frame.id)), .sleepSoon]
        case .command, .setVolume, .setMuted:
            if let error = execute(frame.message) {
                return [.send(.failure(replyTo: frame.id, Failure(code: error)))]
            }
            return [.send(.ok(replyTo: frame.id)), .sendState]
        }
    }
}
