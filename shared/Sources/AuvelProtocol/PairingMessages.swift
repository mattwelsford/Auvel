import Foundation

// Pairing messages, protocol §6. Same envelope as control frames: {"v":1,"id":n,"type":"pair_commit","body":{...}}.
// Binary values (public keys, commitments, nonces, MACs) are base64 strings on the wire.

public struct PairHello: Codable, Equatable, Sendable {
    public var versions: [Int]
    public var deviceID: UUID
    public var deviceName: String
    public var publicKey: Data

    public init(versions: [Int], deviceID: UUID, deviceName: String, publicKey: Data) {
        self.versions = versions
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.publicKey = publicKey
    }

    enum CodingKeys: String, CodingKey {
        case versions
        case deviceID = "device_id"
        case deviceName = "device_name"
        case publicKey = "public_key"
    }
}

public struct PairHelloAck: Codable, Equatable, Sendable {
    public var macID: UUID
    public var macName: String
    public var publicKey: Data

    public init(macID: UUID, macName: String, publicKey: Data) {
        self.macID = macID
        self.macName = macName
        self.publicKey = publicKey
    }

    enum CodingKeys: String, CodingKey {
        case macID = "mac_id"
        case macName = "mac_name"
        case publicKey = "public_key"
    }
}

public struct PairCommit: Codable, Equatable, Sendable {
    public var round: Int
    public var commitment: Data
}

public struct PairReveal: Codable, Equatable, Sendable {
    public var round: Int
    public var nonce: Data
}

public struct PairConfirm: Codable, Equatable, Sendable {
    public var mac: Data
}

public enum PairFailureReason: String, Codable, Equatable, Sendable {
    /// A commitment did not match: the typed code differs from the Mac's code, or the session was tampered with.
    case codeMismatch = "code_mismatch"
    /// Final key confirmation failed.
    case confirmationFailed = "confirmation_failed"
    case unsupportedVersion = "unsupported_version"
    /// Another pairing session is in progress, or the pairing window is closed.
    case busy
    /// Message out of order or malformed.
    case protocolError = "protocol_error"
}

public struct PairFailed: Codable, Equatable, Sendable {
    public var reason: PairFailureReason
}

public enum PairMessage: Equatable, Sendable {
    case hello(PairHello)
    case helloAck(PairHelloAck)
    case commit(PairCommit)
    case reveal(PairReveal)
    case confirm(PairConfirm)
    case failed(PairFailed)
}

/// One pairing message with the sender's message id.
public struct PairFrame: Codable, Equatable, Sendable {
    public var id: UInt32
    public var message: PairMessage

    public init(id: UInt32, message: PairMessage) {
        self.id = id
        self.message = message
    }

    private enum Keys: String, CodingKey { case v, id, type, body }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let v = try c.decode(Int.self, forKey: .v)
        guard v == ProtocolVersion.wire else { throw ProtocolError.unsupportedWireVersion(v) }
        id = try c.decode(UInt32.self, forKey: .id)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "pair_hello": message = .hello(try c.decode(PairHello.self, forKey: .body))
        case "pair_hello_ack": message = .helloAck(try c.decode(PairHelloAck.self, forKey: .body))
        case "pair_commit": message = .commit(try c.decode(PairCommit.self, forKey: .body))
        case "pair_reveal": message = .reveal(try c.decode(PairReveal.self, forKey: .body))
        case "pair_confirm": message = .confirm(try c.decode(PairConfirm.self, forKey: .body))
        case "pair_failed": message = .failed(try c.decode(PairFailed.self, forKey: .body))
        default: throw ProtocolError.unknownType(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(ProtocolVersion.wire, forKey: .v)
        try c.encode(id, forKey: .id)
        switch message {
        case .hello(let body):
            try c.encode("pair_hello", forKey: .type); try c.encode(body, forKey: .body)
        case .helloAck(let body):
            try c.encode("pair_hello_ack", forKey: .type); try c.encode(body, forKey: .body)
        case .commit(let body):
            try c.encode("pair_commit", forKey: .type); try c.encode(body, forKey: .body)
        case .reveal(let body):
            try c.encode("pair_reveal", forKey: .type); try c.encode(body, forKey: .body)
        case .confirm(let body):
            try c.encode("pair_confirm", forKey: .type); try c.encode(body, forKey: .body)
        case .failed(let body):
            try c.encode("pair_failed", forKey: .type); try c.encode(body, forKey: .body)
        }
    }
}
