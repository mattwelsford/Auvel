import CryptoKit
import Foundation
import Testing
@testable import AuvelProtocol

private let phoneID = UUID(uuidString: "6F1C2A54-3B7E-4C1D-9A0B-2E5F8D7C6B4A")!
private let macID = UUID(uuidString: "0C2D9E1F-7A4B-4E3C-8B5A-1D2E3F4A5B6C")!

/// Every frame goes through the wire codec, so the tests also cover pairing encode and decode.
private func wire(_ frame: PairFrame) throws -> PairFrame {
    var reader = FrameCodec.Reader()
    reader.append(try FrameCodec.encode(frame))
    return try #require(try reader.next(PairFrame.self))
}

private struct Outcome {
    var client: Result<PairingResult, PairingError>?
    var server: Result<PairingResult, PairingError>?
    var roundsCompleted = 0
}

/// Runs a full exchange in memory. `tamper` may rewrite any frame in flight (fromClient = true for iPhone → Mac).
private func runPairing(
    clientCode: UInt32, serverCode: UInt32,
    tamper: (inout PairFrame, _ fromClient: Bool) -> Void = { _, _ in }
) throws -> Outcome {
    var client = PairingClient(passkey: Passkey(clientCode)!, deviceID: phoneID, deviceName: "Matt's iPhone")
    var server = PairingServer(passkey: Passkey(serverCode)!, macID: macID, macName: "Matt's MacBook Pro")
    var outcome = Outcome()
    var toServer = [client.start()]
    var toClient: [PairFrame] = []

    for _ in 0..<200 {
        if toServer.isEmpty && toClient.isEmpty { break }
        for var frame in toServer {
            tamper(&frame, true)
            do {
                let (send, result) = try server.receive(try wire(frame))
                toClient += send
                if let result { outcome.server = .success(result) }
            } catch let error as PairingError {
                outcome.server = .failure(error)
                toClient = [server.failureFrame(error.reason)]
            }
        }
        toServer = []
        for var frame in toClient {
            tamper(&frame, false)
            if case .reveal(let r) = frame.message { outcome.roundsCompleted = r.round }
            do {
                let (send, result) = try client.receive(try wire(frame))
                toServer += send
                if let result { outcome.client = .success(result) }
            } catch let error as PairingError {
                if outcome.client == nil { outcome.client = .failure(error) }
                if !error.fromPeer { toServer = [client.failureFrame(error.reason)] }
            }
        }
        toClient = []
    }
    return outcome
}

@Suite("Pairing")
struct PairingTests {
    @Test("Matching codes give both sides the same key and identities")
    func matchingCodesSucceed() throws {
        let outcome = try runPairing(clientCode: 482_916, serverCode: 482_916)
        let client = try #require(try outcome.client?.get())
        let server = try #require(try outcome.server?.get())
        #expect(client.keyData == server.keyData)
        #expect(client.keyData.count == 32)
        #expect(client.peerID == macID && client.peerName == "Matt's MacBook Pro")
        #expect(server.peerID == phoneID && server.peerName == "Matt's iPhone")
        #expect(outcome.roundsCompleted == 20)
    }

    @Test("Two sessions with the same code derive different keys")
    func keysAreFresh() throws {
        let a = try #require(try runPairing(clientCode: 123_456, serverCode: 123_456).client?.get())
        let b = try #require(try runPairing(clientCode: 123_456, serverCode: 123_456).client?.get())
        #expect(a.keyData != b.keyData)
    }

    @Test("A wrong code fails on the first differing bit and gives no key",
          arguments: [(482_916 as UInt32, 482_917 as UInt32), (0, 999_999), (999_999, 524_287), (1, 0)])
    func wrongCodeFails(serverCode: UInt32, clientCode: UInt32) throws {
        let outcome = try runPairing(clientCode: clientCode, serverCode: serverCode)
        #expect(throws: PairingError.self) { try outcome.server?.get() }
        #expect(throws: PairingError.self) { try outcome.client?.get() }
        let firstDifferingBit = (serverCode ^ clientCode).leadingZeroBitCount - (32 - Passkey.bitCount) + 1
        #expect(outcome.roundsCompleted == firstDifferingBit - 1)
        if case .failure(let error) = outcome.server { #expect(error.reason == .codeMismatch) }
    }

    @Test("A modified commitment is detected")
    func tamperedCommitmentFails() throws {
        let outcome = try runPairing(clientCode: 482_916, serverCode: 482_916) { frame, fromClient in
            if fromClient, case .commit(var c) = frame.message, c.round == 7 {
                c.commitment[0] ^= 0xFF
                frame.message = .commit(c)
            }
        }
        #expect(throws: PairingError.self) { try outcome.server?.get() }
        #expect(throws: PairingError.self) { try outcome.client?.get() }
    }

    @Test("A substituted public key (man in the middle) is detected")
    func substitutedKeyFails() throws {
        let attacker = P256.KeyAgreement.PrivateKey().publicKey.x963Representation
        let outcome = try runPairing(clientCode: 482_916, serverCode: 482_916) { frame, fromClient in
            if !fromClient, case .helloAck(var ack) = frame.message {
                ack.publicKey = attacker
                frame.message = .helloAck(ack)
            }
        }
        #expect(throws: PairingError.self) { try outcome.client?.get() }
        #expect(throws: PairingError.self) { try outcome.server?.get() }
    }

    @Test("A modified confirmation is rejected")
    func tamperedConfirmationFails() throws {
        let outcome = try runPairing(clientCode: 482_916, serverCode: 482_916) { frame, fromClient in
            if fromClient, case .confirm(var c) = frame.message {
                c.mac[5] ^= 0x01
                frame.message = .confirm(c)
            }
        }
        if case .failure(let error) = outcome.server { #expect(error.reason == .confirmationFailed) } else { Issue.record("Server should fail") }
        #expect(throws: PairingError.self) { try outcome.client?.get() }
    }

    @Test("Out-of-order messages are a protocol error")
    func outOfOrderFails() throws {
        var server = PairingServer(passkey: Passkey(1)!, macID: macID, macName: "Mac")
        do {
            _ = try server.receive(PairFrame(id: 1, message: .reveal(PairReveal(round: 1, nonce: Data(count: 16)))))
            Issue.record("Expected a protocol error")
        } catch {
            #expect(error == PairingError(reason: .protocolError, fromPeer: false))
        }
        #expect(server.state == .failed)
    }

    @Test("An unsupported protocol version is refused")
    func unsupportedVersionFails() throws {
        var server = PairingServer(passkey: Passkey(1)!, macID: macID, macName: "Mac")
        let hello = PairHello(versions: [99], deviceID: phoneID, deviceName: "Phone",
                              publicKey: P256.KeyAgreement.PrivateKey().publicKey.x963Representation)
        do {
            _ = try server.receive(PairFrame(id: 1, message: .hello(hello)))
            Issue.record("Expected unsupported version")
        } catch {
            #expect(error == PairingError(reason: .unsupportedVersion, fromPeer: false))
        }
    }

    @Test("A failure from the peer is surfaced as such")
    func peerFailureIsReported() throws {
        var client = PairingClient(passkey: Passkey(1)!, deviceID: phoneID, deviceName: "Phone")
        _ = client.start()
        do {
            _ = try client.receive(PairFrame(id: 1, message: .failed(PairFailed(reason: .busy))))
            Issue.record("Expected the peer's failure")
        } catch {
            #expect(error == PairingError(reason: .busy, fromPeer: true))
        }
    }
}

@Suite("Passkey")
struct PasskeyTests {
    @Test func parsesWithAndWithoutSpace() {
        #expect(Passkey(string: "482 916")?.value == 482_916)
        #expect(Passkey(string: "482916")?.value == 482_916)
        #expect(Passkey(string: "000001")?.value == 1)
    }

    @Test func rejectsBadInput() {
        #expect(Passkey(string: "48291") == nil)
        #expect(Passkey(string: "4829166") == nil)
        #expect(Passkey(string: "48a916") == nil)
        #expect(Passkey(1_000_000) == nil)
    }

    @Test func formatsForDisplay() {
        #expect(Passkey(482_916)!.description == "482 916")
        #expect(Passkey(7)!.description == "000 007")
    }

    @Test func bitsAreMostSignificantFirst() {
        let key = Passkey(0b1000_0000_0000_0000_0001)!
        #expect(key.bit(1) == 1)
        #expect((2...19).allSatisfy { key.bit($0) == 0 })
        #expect(key.bit(20) == 1)
    }

    @Test func randomCodesAreInRange() {
        for _ in 0..<1000 { #expect(Passkey.random().value <= 999_999) }
    }
}
