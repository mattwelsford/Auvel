import Foundation

// Message types for protocol version 1. See docs/phase-2/protocol.md §5.
// Wire shape: {"v":1,"id":7,"type":"set_volume","body":{"level":0.62}}

// MARK: - Bodies

public struct Hello: Codable, Equatable, Sendable {
    public var versions: [Int]
    public var deviceID: UUID
    public var deviceName: String
    public var appVersion: String

    public init(versions: [Int], deviceID: UUID, deviceName: String, appVersion: String) {
        self.versions = versions
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.appVersion = appVersion
    }

    enum CodingKeys: String, CodingKey {
        case versions
        case deviceID = "device_id"
        case deviceName = "device_name"
        case appVersion = "app_version"
    }
}

public enum MediaCommand: String, Codable, Equatable, Sendable {
    case playPause = "play_pause"
    case next
    case previous
}

public struct HelloAck: Codable, Equatable, Sendable {
    public var version: Int
    public var macName: String
    public var model: String
    public var appVersion: String

    public init(version: Int, macName: String, model: String, appVersion: String) {
        self.version = version
        self.macName = macName
        self.model = model
        self.appVersion = appVersion
    }

    enum CodingKeys: String, CodingKey {
        case version
        case macName = "mac_name"
        case model
        case appVersion = "app_version"
    }
}

public struct MacState: Codable, Equatable, Sendable {
    /// Output volume, 0...1.
    public var volume: Double
    public var muted: Bool
    /// False when the current output has no software volume control (F7).
    public var volumeSettable: Bool
    /// User-visible name of the current output device.
    public var outputName: String
    /// True when Accessibility is granted, so media keys can be posted.
    public var mediaKeysAllowed: Bool

    public init(volume: Double, muted: Bool, volumeSettable: Bool, outputName: String, mediaKeysAllowed: Bool) {
        self.volume = volume
        self.muted = muted
        self.volumeSettable = volumeSettable
        self.outputName = outputName
        self.mediaKeysAllowed = mediaKeysAllowed
    }

    enum CodingKeys: String, CodingKey {
        case volume
        case muted
        case volumeSettable = "volume_settable"
        case outputName = "output_name"
        case mediaKeysAllowed = "media_keys_allowed"
    }
}

public enum ErrorCode: String, Codable, Equatable, Sendable {
    case unsupportedVersion = "unsupported_version"
    case mediaKeysNotAllowed = "media_keys_not_allowed"
    case volumeNotSettable = "volume_not_settable"
    case badRequest = "bad_request"
    case rateLimited = "rate_limited"
    case internalError = "internal"
}

public struct Failure: Codable, Equatable, Sendable {
    public var code: ErrorCode
    /// Set with `unsupportedVersion`: the lowest protocol version the Mac accepts.
    public var minimumVersion: Int?

    public init(code: ErrorCode, minimumVersion: Int? = nil) {
        self.code = code
        self.minimumVersion = minimumVersion
    }

    enum CodingKeys: String, CodingKey {
        case code
        case minimumVersion = "minimum_version"
    }
}

// MARK: - Messages

/// Messages sent from the iPhone to the Mac.
public enum ClientMessage: Equatable, Sendable {
    case hello(Hello)
    case command(MediaCommand)
    /// Sets output volume. Must be within 0...1.
    case setVolume(Double)
    case setMuted(Bool)
    case sleep
    case getState
    case ping
}

/// Messages sent from the Mac to the iPhone.
public enum MacMessage: Equatable, Sendable {
    case helloAck(HelloAck)
    case state(MacState)
    case ok(replyTo: UInt32)
    case failure(replyTo: UInt32, Failure)
    case pong
}

public enum ProtocolError: Error, Equatable {
    case unsupportedWireVersion(Int)
    case unknownType(String)
    case valueOutOfRange(String)
    case frameTooLarge(Int)
}

// MARK: - Frames

private enum FrameKeys: String, CodingKey {
    case v, id, type, body
    case replyTo = "reply_to"
}

private struct LevelBody: Codable { var level: Double }
private struct MutedBody: Codable { var muted: Bool }
private struct CommandBody: Codable { var command: MediaCommand }

/// One message from the iPhone, with the sender's request id.
public struct ClientFrame: Codable, Equatable, Sendable {
    public var id: UInt32
    public var message: ClientMessage

    public init(id: UInt32, message: ClientMessage) {
        self.id = id
        self.message = message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FrameKeys.self)
        let v = try c.decode(Int.self, forKey: .v)
        guard v == ProtocolVersion.wire else { throw ProtocolError.unsupportedWireVersion(v) }
        id = try c.decode(UInt32.self, forKey: .id)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hello":
            message = .hello(try c.decode(Hello.self, forKey: .body))
        case "command":
            message = .command(try c.decode(CommandBody.self, forKey: .body).command)
        case "set_volume":
            let level = try c.decode(LevelBody.self, forKey: .body).level
            guard (0...1).contains(level) else { throw ProtocolError.valueOutOfRange("level") }
            message = .setVolume(level)
        case "set_muted":
            message = .setMuted(try c.decode(MutedBody.self, forKey: .body).muted)
        case "sleep":
            message = .sleep
        case "get_state":
            message = .getState
        case "ping":
            message = .ping
        default:
            throw ProtocolError.unknownType(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: FrameKeys.self)
        try c.encode(ProtocolVersion.wire, forKey: .v)
        try c.encode(id, forKey: .id)
        switch message {
        case .hello(let hello):
            try c.encode("hello", forKey: .type)
            try c.encode(hello, forKey: .body)
        case .command(let command):
            try c.encode("command", forKey: .type)
            try c.encode(CommandBody(command: command), forKey: .body)
        case .setVolume(let level):
            guard (0...1).contains(level) else { throw ProtocolError.valueOutOfRange("level") }
            try c.encode("set_volume", forKey: .type)
            try c.encode(LevelBody(level: level), forKey: .body)
        case .setMuted(let muted):
            try c.encode("set_muted", forKey: .type)
            try c.encode(MutedBody(muted: muted), forKey: .body)
        case .sleep:
            try c.encode("sleep", forKey: .type)
        case .getState:
            try c.encode("get_state", forKey: .type)
        case .ping:
            try c.encode("ping", forKey: .type)
        }
    }
}

/// One message from the Mac, with the sender's message id.
public struct MacFrame: Codable, Equatable, Sendable {
    public var id: UInt32
    public var message: MacMessage

    public init(id: UInt32, message: MacMessage) {
        self.id = id
        self.message = message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FrameKeys.self)
        let v = try c.decode(Int.self, forKey: .v)
        guard v == ProtocolVersion.wire else { throw ProtocolError.unsupportedWireVersion(v) }
        id = try c.decode(UInt32.self, forKey: .id)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hello_ack":
            message = .helloAck(try c.decode(HelloAck.self, forKey: .body))
        case "state":
            let state = try c.decode(MacState.self, forKey: .body)
            guard (0...1).contains(state.volume) else { throw ProtocolError.valueOutOfRange("volume") }
            message = .state(state)
        case "ok":
            message = .ok(replyTo: try c.decode(UInt32.self, forKey: .replyTo))
        case "failure":
            message = .failure(
                replyTo: try c.decode(UInt32.self, forKey: .replyTo),
                try c.decode(Failure.self, forKey: .body)
            )
        case "pong":
            message = .pong
        default:
            throw ProtocolError.unknownType(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: FrameKeys.self)
        try c.encode(ProtocolVersion.wire, forKey: .v)
        try c.encode(id, forKey: .id)
        switch message {
        case .helloAck(let ack):
            try c.encode("hello_ack", forKey: .type)
            try c.encode(ack, forKey: .body)
        case .state(let state):
            try c.encode("state", forKey: .type)
            try c.encode(state, forKey: .body)
        case .ok(let replyTo):
            try c.encode("ok", forKey: .type)
            try c.encode(replyTo, forKey: .replyTo)
        case .failure(let replyTo, let failure):
            try c.encode("failure", forKey: .type)
            try c.encode(replyTo, forKey: .replyTo)
            try c.encode(failure, forKey: .body)
        case .pong:
            try c.encode("pong", forKey: .type)
        }
    }
}
