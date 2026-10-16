import CryptoKit
import Foundation

// Pairing, protocol §6. Passkey Entry style: ECDH plus 20 commit-reveal rounds, one per bit of the code.
// Both roles are plain state machines: feed in a received frame, get back the frames to send.
// Transport, timeouts and the "new code after failure" rule live in the apps.

/// The 6-digit code shown on the Mac.
public struct Passkey: Equatable, Sendable, CustomStringConvertible {
    public static let bitCount = 20
    public let value: UInt32

    public init?(_ value: UInt32) {
        guard value <= 999_999 else { return nil }
        self.value = value
    }

    /// Parses six digits, ignoring spaces: "482 916" or "482916".
    public init?(string: String) {
        let digits = string.filter { !$0.isWhitespace }
        guard digits.count == 6, digits.allSatisfy(\.isASCII), let value = UInt32(digits) else { return nil }
        self.init(value)
    }

    public static func random() -> Passkey {
        var generator = SystemRandomNumberGenerator()
        return Passkey(UInt32.random(in: 0...999_999, using: &generator))!
    }

    /// Bit `round` of the code, 1-based, most significant first.
    func bit(_ round: Int) -> UInt8 {
        UInt8((value >> UInt32(Passkey.bitCount - round)) & 1)
    }

    /// Display form, "482 916".
    public var description: String {
        let s = String(format: "%06u", value)
        return "\(s.prefix(3)) \(s.suffix(3))"
    }
}

/// Outcome of a successful pairing, stored in the Keychain by the app.
public struct PairingResult: Equatable, Sendable {
    public let peerID: UUID
    public let peerName: String
    /// 256-bit key used as the TLS pre-shared key (protocol §7). Raw bytes, for the Keychain.
    public let keyData: Data

    public init(peerID: UUID, peerName: String, key: SymmetricKey) {
        self.peerID = peerID
        self.peerName = peerName
        self.keyData = key.withUnsafeBytes { Data($0) }
    }
}

public struct PairingError: Error, Equatable {
    public let reason: PairFailureReason
    /// True when the peer reported the failure, false when this side detected it.
    public let fromPeer: Bool

    public init(reason: PairFailureReason, fromPeer: Bool) {
        self.reason = reason
        self.fromPeer = fromPeer
    }
}

enum PairingCrypto {
    static let nonceLength = 16

    static func nonce() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<nonceLength).map { _ in UInt8.random(in: 0...255, using: &generator) })
    }

    /// `HMAC(nonce, ownKey ‖ peerKey ‖ (0x80 | bit))`.
    static func commitment(nonce: Data, ownKey: Data, peerKey: Data, bit: UInt8) -> Data {
        var message = ownKey
        message.append(peerKey)
        message.append(0x80 | bit)
        return Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: nonce)))
    }

    static func confirmation(key: SymmetricKey, label: String, transcript: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(label.utf8) + transcript, using: key))
    }

    static func deriveKey(shared: SharedSecret, clientNonce: Data, macNonce: Data,
                          clientKey: Data, macKey: Data, transcript: Data) -> SymmetricKey {
        shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: clientNonce + macNonce,
            sharedInfo: Data("auvel pairing v1".utf8) + clientKey + macKey + transcript,
            outputByteCount: 32
        )
    }

    /// Constant-time comparison for MACs and commitments.
    static func equal(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

/// Builds `T`: SHA-256 over identities, both public keys and every commitment and nonce in round order.
struct Transcript {
    private var hash = SHA256()

    mutating func add(_ data: Data) {
        var length = UInt16(data.count).bigEndian
        hash.update(data: Data(bytes: &length, count: 2))
        hash.update(data: data)
    }

    mutating func add(_ uuid: UUID) {
        add(withUnsafeBytes(of: uuid.uuid) { Data($0) })
    }

    mutating func add(_ string: String) {
        add(Data(string.utf8))
    }

    func digest() -> Data {
        Data(hash.finalize())
    }
}

// MARK: - iPhone side

public struct PairingClient {
    public enum State: Equatable, Sendable { case idle, awaitingHelloAck, inRound(Int), awaitingConfirm, done, failed }

    public private(set) var state: State = .idle
    private let passkey: Passkey
    private let deviceID: UUID
    private let deviceName: String
    private let privateKey = P256.KeyAgreement.PrivateKey()
    private var macID = UUID()
    private var macName = ""
    private var macKey = Data()
    private var shared: SharedSecret?
    private var transcript = Transcript()
    private var ownNonce = Data()
    private var peerCommitment = Data()
    private var lastClientNonce = Data()
    private var lastMacNonce = Data()
    private var key: SymmetricKey?
    private var nextID: UInt32 = 1

    public init(passkey: Passkey, deviceID: UUID, deviceName: String) {
        self.passkey = passkey
        self.deviceID = deviceID
        self.deviceName = deviceName
    }

    private var ownKey: Data { privateKey.publicKey.x963Representation }

    private mutating func frame(_ message: PairMessage) -> PairFrame {
        defer { nextID += 1 }
        return PairFrame(id: nextID, message: message)
    }

    public mutating func start() -> PairFrame {
        state = .awaitingHelloAck
        return frame(.hello(PairHello(versions: ProtocolVersion.supported, deviceID: deviceID, deviceName: deviceName, publicKey: ownKey)))
    }

    /// Handles one frame from the Mac. Returns frames to send and, when pairing completes, the result.
    public mutating func receive(_ incoming: PairFrame) throws(PairingError) -> (send: [PairFrame], result: PairingResult?) {
        if case .failed(let failure) = incoming.message {
            state = .failed
            throw PairingError(reason: failure.reason, fromPeer: true)
        }
        switch (state, incoming.message) {
        case (.awaitingHelloAck, .helloAck(let ack)):
            guard let peer = try? P256.KeyAgreement.PublicKey(x963Representation: ack.publicKey),
                  let secret = try? privateKey.sharedSecretFromKeyAgreement(with: peer) else {
                return try fail(.protocolError)
            }
            macID = ack.macID
            macName = ack.macName
            macKey = ack.publicKey
            shared = secret
            transcript.add(deviceID); transcript.add(deviceName); transcript.add(ownKey)
            transcript.add(macID); transcript.add(macName); transcript.add(macKey)
            return (send: [commit(round: 1)], result: nil)

        case (.inRound(let round), .commit(let c)) where c.round == round && peerCommitment.isEmpty:
            peerCommitment = c.commitment
            transcript.add(c.commitment)
            transcript.add(ownNonce)
            return (send: [frame(.reveal(PairReveal(round: round, nonce: ownNonce)))], result: nil)

        case (.inRound(let round), .reveal(let r)) where r.round == round && !peerCommitment.isEmpty:
            let expected = PairingCrypto.commitment(nonce: r.nonce, ownKey: macKey, peerKey: ownKey, bit: passkey.bit(round))
            guard PairingCrypto.equal(expected, peerCommitment) else { return try fail(.codeMismatch) }
            transcript.add(r.nonce)
            if round < Passkey.bitCount {
                return (send: [commit(round: round + 1)], result: nil)
            }
            lastClientNonce = ownNonce
            lastMacNonce = r.nonce
            let t = transcript.digest()
            let k = PairingCrypto.deriveKey(shared: shared!, clientNonce: lastClientNonce, macNonce: lastMacNonce,
                                            clientKey: ownKey, macKey: macKey, transcript: t)
            key = k
            state = .awaitingConfirm
            return (send: [frame(.confirm(PairConfirm(mac: PairingCrypto.confirmation(key: k, label: "client", transcript: t))))], result: nil)

        case (.awaitingConfirm, .confirm(let c)):
            let expected = PairingCrypto.confirmation(key: key!, label: "mac", transcript: transcript.digest())
            guard PairingCrypto.equal(expected, c.mac) else { return try fail(.confirmationFailed) }
            state = .done
            return (send: [], result: PairingResult(peerID: macID, peerName: macName, key: key!))

        default:
            return try fail(.protocolError)
        }
    }

    private mutating func commit(round: Int) -> PairFrame {
        state = .inRound(round)
        ownNonce = PairingCrypto.nonce()
        peerCommitment = Data()
        let c = PairingCrypto.commitment(nonce: ownNonce, ownKey: ownKey, peerKey: macKey, bit: passkey.bit(round))
        transcript.add(c)
        return frame(.commit(PairCommit(round: round, commitment: c)))
    }

    /// Marks the session failed. The app sends `failureFrame` before closing the connection.
    private mutating func fail(_ reason: PairFailureReason) throws(PairingError) -> (send: [PairFrame], result: PairingResult?) {
        state = .failed
        throw PairingError(reason: reason, fromPeer: false)
    }

    /// Frame telling the peer why this side gave up.
    public mutating func failureFrame(_ reason: PairFailureReason) -> PairFrame {
        frame(.failed(PairFailed(reason: reason)))
    }
}

// MARK: - Mac side

public struct PairingServer {
    public enum State: Equatable, Sendable { case awaitingHello, inRound(Int), awaitingConfirm, done, failed }

    public private(set) var state: State = .awaitingHello
    private let passkey: Passkey
    private let macID: UUID
    private let macName: String
    private let privateKey = P256.KeyAgreement.PrivateKey()
    private var deviceID = UUID()
    private var deviceName = ""
    private var clientKey = Data()
    private var shared: SharedSecret?
    private var transcript = Transcript()
    private var ownNonce = Data()
    private var peerCommitment = Data()
    private var nextID: UInt32 = 1

    public init(passkey: Passkey, macID: UUID, macName: String) {
        self.passkey = passkey
        self.macID = macID
        self.macName = macName
    }

    private var ownKey: Data { privateKey.publicKey.x963Representation }

    private mutating func frame(_ message: PairMessage) -> PairFrame {
        defer { nextID += 1 }
        return PairFrame(id: nextID, message: message)
    }

    /// The iPhone's identity, known after `pair_hello`.
    public var peer: (id: UUID, name: String) { (deviceID, deviceName) }

    public mutating func receive(_ incoming: PairFrame) throws(PairingError) -> (send: [PairFrame], result: PairingResult?) {
        if case .failed(let failure) = incoming.message {
            state = .failed
            throw PairingError(reason: failure.reason, fromPeer: true)
        }
        switch (state, incoming.message) {
        case (.awaitingHello, .hello(let hello)):
            guard ProtocolVersion.negotiate(client: hello.versions, server: ProtocolVersion.supported) != nil else {
                return try fail(.unsupportedVersion)
            }
            guard let peer = try? P256.KeyAgreement.PublicKey(x963Representation: hello.publicKey),
                  let secret = try? privateKey.sharedSecretFromKeyAgreement(with: peer) else {
                return try fail(.protocolError)
            }
            deviceID = hello.deviceID
            deviceName = hello.deviceName
            clientKey = hello.publicKey
            shared = secret
            transcript.add(deviceID); transcript.add(deviceName); transcript.add(clientKey)
            transcript.add(macID); transcript.add(macName); transcript.add(ownKey)
            state = .inRound(1)
            return (send: [frame(.helloAck(PairHelloAck(macID: macID, macName: macName, publicKey: ownKey)))], result: nil)

        case (.inRound(let round), .commit(let c)) where c.round == round && peerCommitment.isEmpty:
            peerCommitment = c.commitment
            ownNonce = PairingCrypto.nonce()
            let own = PairingCrypto.commitment(nonce: ownNonce, ownKey: ownKey, peerKey: clientKey, bit: passkey.bit(round))
            transcript.add(c.commitment)
            transcript.add(own)
            return (send: [frame(.commit(PairCommit(round: round, commitment: own)))], result: nil)

        case (.inRound(let round), .reveal(let r)) where r.round == round && !peerCommitment.isEmpty:
            let expected = PairingCrypto.commitment(nonce: r.nonce, ownKey: clientKey, peerKey: ownKey, bit: passkey.bit(round))
            guard PairingCrypto.equal(expected, peerCommitment) else { return try fail(.codeMismatch) }
            transcript.add(r.nonce)
            transcript.add(ownNonce)
            peerCommitment = Data()
            if round < Passkey.bitCount {
                state = .inRound(round + 1)
            } else {
                state = .awaitingConfirm
                lastNonces = (r.nonce, ownNonce)
            }
            return (send: [frame(.reveal(PairReveal(round: round, nonce: ownNonce)))], result: nil)

        case (.awaitingConfirm, .confirm(let c)):
            let t = transcript.digest()
            let k = PairingCrypto.deriveKey(shared: shared!, clientNonce: lastNonces.client, macNonce: lastNonces.mac,
                                            clientKey: clientKey, macKey: ownKey, transcript: t)
            let expected = PairingCrypto.confirmation(key: k, label: "client", transcript: t)
            guard PairingCrypto.equal(expected, c.mac) else { return try fail(.confirmationFailed) }
            state = .done
            let reply = frame(.confirm(PairConfirm(mac: PairingCrypto.confirmation(key: k, label: "mac", transcript: t))))
            return (send: [reply], result: PairingResult(peerID: deviceID, peerName: deviceName, key: k))

        default:
            return try fail(.protocolError)
        }
    }

    private var lastNonces: (client: Data, mac: Data) = (Data(), Data())

    private mutating func fail(_ reason: PairFailureReason) throws(PairingError) -> (send: [PairFrame], result: PairingResult?) {
        state = .failed
        throw PairingError(reason: reason, fromPeer: false)
    }

    public mutating func failureFrame(_ reason: PairFailureReason) -> PairFrame {
        frame(.failed(PairFailed(reason: reason)))
    }
}
