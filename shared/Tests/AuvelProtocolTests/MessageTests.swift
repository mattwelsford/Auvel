import Foundation
import Testing
@testable import AuvelProtocol

/// Fixtures are the canonical wire form (sorted keys). The same files feed the T2 contract tests in P4.
private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    let data = try Data(contentsOf: url)
    // Files end with a newline; the wire form does not.
    return data.last == UInt8(ascii: "\n") ? data.dropLast() : data
}

private func encodeCanonical<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private let iPhoneID = UUID(uuidString: "6F1C2A54-3B7E-4C1D-9A0B-2E5F8D7C6B4A")!

@Suite("Client messages")
struct ClientMessageTests {
    static let cases: [(String, ClientFrame)] = [
        ("client_hello", ClientFrame(id: 1, message: .hello(Hello(versions: [1], deviceID: iPhoneID, deviceName: "Matt's iPhone", appVersion: "1.0")))),
        ("client_command_play_pause", ClientFrame(id: 2, message: .command(.playPause))),
        ("client_set_volume", ClientFrame(id: 3, message: .setVolume(0.62))),
        ("client_set_muted", ClientFrame(id: 4, message: .setMuted(true))),
        ("client_sleep", ClientFrame(id: 5, message: .sleep)),
    ]

    @Test("Fixture decodes to the expected message", arguments: ClientMessageTests.cases)
    func decodesFixture(name: String, expected: ClientFrame) throws {
        let decoded = try JSONDecoder().decode(ClientFrame.self, from: try fixture(name))
        #expect(decoded == expected)
    }

    @Test("Message encodes to the fixture bytes", arguments: ClientMessageTests.cases)
    func encodesToFixture(name: String, frame: ClientFrame) throws {
        #expect(try encodeCanonical(frame) == (try fixture(name)))
    }

    @Test("Messages without fixtures round-trip")
    func roundTrips() throws {
        for message in [ClientMessage.getState, .ping, .command(.next), .command(.previous), .setMuted(false), .setVolume(0), .setVolume(1)] {
            let frame = ClientFrame(id: 9, message: message)
            let decoded = try JSONDecoder().decode(ClientFrame.self, from: try encodeCanonical(frame))
            #expect(decoded == frame)
        }
    }

    @Test("Volume outside 0...1 is rejected when decoding")
    func rejectsOutOfRangeVolume() throws {
        #expect(throws: ProtocolError.valueOutOfRange("level")) {
            try JSONDecoder().decode(ClientFrame.self, from: try fixture("invalid_client_set_volume_out_of_range"))
        }
    }

    @Test("Volume outside 0...1 is rejected when encoding")
    func refusesToEncodeOutOfRangeVolume() {
        #expect(throws: ProtocolError.valueOutOfRange("level")) {
            try encodeCanonical(ClientFrame(id: 1, message: .setVolume(-0.1)))
        }
    }

    @Test("Unknown message type is rejected")
    func rejectsUnknownType() throws {
        #expect(throws: ProtocolError.unknownType("teleport")) {
            try JSONDecoder().decode(ClientFrame.self, from: try fixture("invalid_client_unknown_type"))
        }
    }

    @Test("Unknown wire version is rejected")
    func rejectsWireVersion() throws {
        #expect(throws: ProtocolError.unsupportedWireVersion(2)) {
            try JSONDecoder().decode(ClientFrame.self, from: try fixture("invalid_client_wire_version"))
        }
    }
}

@Suite("Mac messages")
struct MacMessageTests {
    static let cases: [(String, MacFrame)] = [
        ("mac_hello_ack", MacFrame(id: 1, message: .helloAck(HelloAck(version: 1, macName: "Matt's MacBook Pro", model: "Mac15,3", appVersion: "1.0")))),
        ("mac_state", MacFrame(id: 2, message: .state(MacState(volume: 0.62, muted: false, volumeSettable: true, outputName: "MacBook Pro Speakers", mediaKeysAllowed: true)))),
        ("mac_ok", MacFrame(id: 3, message: .ok(replyTo: 3))),
        ("mac_failure_media_keys", MacFrame(id: 4, message: .failure(replyTo: 2, Failure(code: .mediaKeysNotAllowed)))),
        ("mac_failure_unsupported_version", MacFrame(id: 5, message: .failure(replyTo: 1, Failure(code: .unsupportedVersion, minimumVersion: 2)))),
    ]

    @Test("Fixture decodes to the expected message", arguments: MacMessageTests.cases)
    func decodesFixture(name: String, expected: MacFrame) throws {
        let decoded = try JSONDecoder().decode(MacFrame.self, from: try fixture(name))
        #expect(decoded == expected)
    }

    @Test("Message encodes to the fixture bytes", arguments: MacMessageTests.cases)
    func encodesToFixture(name: String, frame: MacFrame) throws {
        #expect(try encodeCanonical(frame) == (try fixture(name)))
    }

    @Test("Pong round-trips")
    func pongRoundTrips() throws {
        let frame = MacFrame(id: 6, message: .pong)
        #expect(try JSONDecoder().decode(MacFrame.self, from: try encodeCanonical(frame)) == frame)
    }
}

@Suite("Version negotiation")
struct VersionTests {
    @Test func picksHighestCommonVersion() {
        #expect(ProtocolVersion.negotiate(client: [1, 2, 3], server: [1, 2]) == 2)
    }

    @Test func returnsNilWithNoOverlap() {
        #expect(ProtocolVersion.negotiate(client: [2], server: [1]) == nil)
    }

    @Test func currentIsSupported() {
        #expect(ProtocolVersion.supported.contains(ProtocolVersion.current))
    }
}

@Suite("Framing")
struct FrameCodecTests {
    @Test("A frame split across reads is reassembled")
    func reassemblesSplitFrame() throws {
        let frame = ClientFrame(id: 1, message: .setVolume(0.5))
        let bytes = try FrameCodec.encode(frame)
        var reader = FrameCodec.Reader()
        reader.append(bytes.prefix(3))
        #expect(try reader.next(ClientFrame.self) == nil)
        reader.append(bytes.dropFirst(3).prefix(5))
        #expect(try reader.next(ClientFrame.self) == nil)
        reader.append(bytes.dropFirst(8))
        #expect(try reader.next(ClientFrame.self) == frame)
        #expect(try reader.next(ClientFrame.self) == nil)
    }

    @Test("Two frames in one read are both returned in order")
    func readsBackToBackFrames() throws {
        let a = ClientFrame(id: 1, message: .ping)
        let b = ClientFrame(id: 2, message: .command(.next))
        var reader = FrameCodec.Reader()
        reader.append(try FrameCodec.encode(a) + FrameCodec.encode(b))
        #expect(try reader.next(ClientFrame.self) == a)
        #expect(try reader.next(ClientFrame.self) == b)
    }

    @Test("A length prefix over the limit is rejected before the payload arrives")
    func rejectsOversizedLength() {
        var reader = FrameCodec.Reader()
        let tooBig = UInt32(FrameCodec.maxPayloadLength + 1)
        reader.append(Data([UInt8(tooBig >> 24), UInt8((tooBig >> 16) & 0xFF), UInt8((tooBig >> 8) & 0xFF), UInt8(tooBig & 0xFF)]))
        #expect(throws: ProtocolError.frameTooLarge(Int(tooBig))) {
            try reader.next(ClientFrame.self)
        }
    }

    @Test("Bonjour service type matches the Info.plist entry")
    func bonjourServiceType() {
        #expect(Bonjour.serviceType == "_auvel._tcp")
    }
}
