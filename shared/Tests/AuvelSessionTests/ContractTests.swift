import AuvelProtocol
import Foundation
import Testing
@testable import AuvelSession

// T2 contract tests: the shared fixtures run through the Mac side (MacSessionLogic, used by ControlServer)
// and the iPhone side (ClientSessionLogic, used by RemoteSession).

private let fixtureDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("AuvelProtocolTests/Fixtures")

private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let data = try Data(contentsOf: fixtureDirectory.appendingPathComponent("\(name).json"))
    return try JSONDecoder().decode(T.self, from: data)
}

private let identity = MacIdentity(name: "Matt's MacBook Pro", model: "Mac15,3", appVersion: "1.0")
private let phoneID = UUID(uuidString: "6F1C2A54-3B7E-4C1D-9A0B-2E5F8D7C6B4A")!

/// A Mac session that has already accepted `client_hello`.
private func authenticatedMac() throws -> MacSessionLogic {
    var mac = MacSessionLogic()
    _ = mac.handle(try fixture("client_hello", as: ClientFrame.self), identity: identity) { _ in nil }
    return mac
}

/// Every fixture file must appear in exactly one contract case below.
private let coveredFixtures: Set<String> = [
    "client_hello", "client_command_play_pause", "client_set_volume", "client_set_muted", "client_sleep",
    "invalid_client_set_volume_out_of_range", "invalid_client_unknown_type", "invalid_client_wire_version",
    "mac_hello_ack", "mac_state", "mac_ok", "mac_failure_media_keys", "mac_failure_unsupported_version",
]

@Suite("Contract: fixtures")
struct FixtureCoverageTests {
    @Test("Every fixture file has a contract case")
    func allFixturesCovered() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: fixtureDirectory.path)
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
        #expect(Set(files) == coveredFixtures)
    }

    @Test("Invalid client fixtures are rejected before reaching either side",
          arguments: ["invalid_client_set_volume_out_of_range", "invalid_client_unknown_type", "invalid_client_wire_version"])
    func invalidFixturesRejected(name: String) {
        #expect(throws: ProtocolError.self) { try fixture(name, as: ClientFrame.self) }
    }
}

@Suite("Contract: Mac side")
struct MacSideContractTests {
    @Test("client_hello is acknowledged with identity and state")
    func hello() throws {
        var mac = MacSessionLogic()
        let actions = mac.handle(try fixture("client_hello", as: ClientFrame.self), identity: identity) { _ in nil }
        let ack = HelloAck(version: 1, macName: identity.name, model: identity.model, appVersion: identity.appVersion)
        #expect(actions == [.send(.helloAck(ack)), .sendStateNow, .authenticated])
        #expect(mac.phone?.id == phoneID)
        #expect(mac.phone?.name == "Matt's iPhone")
    }

    @Test("client_command_play_pause executes the command and replies ok")
    func playPause() throws {
        var mac = try authenticatedMac()
        var executed: [ClientMessage] = []
        let actions = mac.handle(try fixture("client_command_play_pause", as: ClientFrame.self), identity: identity) {
            executed.append($0); return nil
        }
        #expect(executed == [.command(.playPause)])
        #expect(actions == [.send(.ok(replyTo: 2)), .sendState])
    }

    @Test("client_command_play_pause without Accessibility replies media_keys_not_allowed")
    func playPauseWithoutPermission() throws {
        var mac = try authenticatedMac()
        let actions = mac.handle(try fixture("client_command_play_pause", as: ClientFrame.self), identity: identity) { _ in
            .mediaKeysNotAllowed
        }
        #expect(actions == [.send(.failure(replyTo: 2, Failure(code: .mediaKeysNotAllowed)))])
    }

    @Test("client_set_volume passes the level through")
    func setVolume() throws {
        var mac = try authenticatedMac()
        var executed: [ClientMessage] = []
        _ = mac.handle(try fixture("client_set_volume", as: ClientFrame.self), identity: identity) { executed.append($0); return nil }
        #expect(executed == [.setVolume(0.62)])
    }

    @Test("client_set_muted on an output without software volume replies volume_not_settable")
    func setMutedNotSettable() throws {
        var mac = try authenticatedMac()
        let actions = mac.handle(try fixture("client_set_muted", as: ClientFrame.self), identity: identity) { _ in .volumeNotSettable }
        #expect(actions == [.send(.failure(replyTo: 4, Failure(code: .volumeNotSettable)))])
    }

    @Test("client_sleep replies ok before sleeping")
    func sleep() throws {
        var mac = try authenticatedMac()
        let actions = mac.handle(try fixture("client_sleep", as: ClientFrame.self), identity: identity) { _ in nil }
        #expect(actions == [.send(.ok(replyTo: 5)), .sleepSoon])
    }

    @Test("A command before hello is refused and the connection closed")
    func commandBeforeHello() throws {
        var mac = MacSessionLogic()
        var executed = false
        let actions = mac.handle(try fixture("client_command_play_pause", as: ClientFrame.self), identity: identity) { _ in
            executed = true; return nil
        }
        #expect(!executed)
        #expect(actions == [.send(.failure(replyTo: 2, Failure(code: .badRequest))), .close])
    }

    @Test("A hello with no common version is refused with the minimum version")
    func helloUnsupported() {
        var mac = MacSessionLogic()
        let hello = ClientFrame(id: 1, message: .hello(Hello(versions: [99], deviceID: phoneID, deviceName: "Phone", appVersion: "9")))
        let actions = mac.handle(hello, identity: identity) { _ in nil }
        #expect(actions == [.send(.failure(replyTo: 1, Failure(code: .unsupportedVersion, minimumVersion: 1))), .close])
        #expect(!mac.isAuthenticated)
    }

    @Test("A second hello is a bad request")
    func secondHello() throws {
        var mac = try authenticatedMac()
        let actions = mac.handle(try fixture("client_hello", as: ClientFrame.self), identity: identity) { _ in nil }
        #expect(actions == [.send(.failure(replyTo: 1, Failure(code: .badRequest)))])
    }

    @Test("ping and get_state")
    func pingAndGetState() throws {
        var mac = try authenticatedMac()
        #expect(mac.handle(ClientFrame(id: 7, message: .ping), identity: identity) { _ in nil } == [.send(.pong)])
        #expect(mac.handle(ClientFrame(id: 8, message: .getState), identity: identity) { _ in nil } == [.sendStateNow])
    }

    @Test("More than 50 frames in one second is rate limited and closed")
    func rateLimit() throws {
        var mac = try authenticatedMac()
        let start = Date()
        var last: [MacSessionLogic.Action] = []
        for i in 0..<51 {
            last = mac.handle(ClientFrame(id: UInt32(10 + i), message: .ping), at: start.addingTimeInterval(Double(i) * 0.01),
                              identity: identity) { _ in nil }
        }
        #expect(last == [.send(.failure(replyTo: 60, Failure(code: .rateLimited))), .close])
    }

    @Test("Frames spread over more than a second are not rate limited")
    func noRateLimitWhenSlow() throws {
        var mac = try authenticatedMac()
        let start = Date().addingTimeInterval(10)
        for i in 0..<100 {
            let actions = mac.handle(ClientFrame(id: UInt32(i), message: .ping), at: start.addingTimeInterval(Double(i) * 0.05),
                                     identity: identity) { _ in nil }
            #expect(actions == [.send(.pong)])
        }
    }
}

@Suite("Contract: iPhone side")
struct ClientSideContractTests {
    private func helloSent() -> ClientSessionLogic {
        var client = ClientSessionLogic()
        _ = client.hello(id: 1, deviceID: phoneID, deviceName: "Matt's iPhone", appVersion: "1.0")
        return client
    }

    @Test("mac_hello_ack connects and records the model")
    func helloAck() throws {
        var client = helloSent()
        #expect(client.handle(try fixture("mac_hello_ack", as: MacFrame.self)) == .becameConnected)
        #expect(client.isConnected)
        #expect(client.macModel == "Mac15,3")
        #expect(client.macVersion == 1)
    }

    @Test("mac_state is stored")
    func state() throws {
        var client = helloSent()
        _ = client.handle(try fixture("mac_hello_ack", as: MacFrame.self))
        _ = client.handle(try fixture("mac_state", as: MacFrame.self))
        #expect(client.state == MacState(volume: 0.62, muted: false, volumeSettable: true,
                                         outputName: "MacBook Pro Speakers", mediaKeysAllowed: true))
    }

    @Test("mac_failure_media_keys is recorded and mac_ok clears it")
    func failureThenOk() throws {
        var client = helloSent()
        _ = client.handle(try fixture("mac_hello_ack", as: MacFrame.self))
        #expect(client.handle(try fixture("mac_failure_media_keys", as: MacFrame.self)) == .none)
        #expect(client.lastFailure == .mediaKeysNotAllowed)
        _ = client.handle(try fixture("mac_ok", as: MacFrame.self))
        #expect(client.lastFailure == nil)
    }

    @Test("mac_failure_unsupported_version for the hello means this app is older")
    func unsupportedVersion() throws {
        var client = helloSent()
        #expect(client.handle(try fixture("mac_failure_unsupported_version", as: MacFrame.self)) == .close)
        #expect(client.phase == .updateRequired(macIsOlder: false))
    }

    @Test("An older Mac (minimum at or below ours) means the Mac needs updating")
    func olderMac() {
        var client = helloSent()
        let failure = MacFrame(id: 1, message: .failure(replyTo: 1, Failure(code: .unsupportedVersion, minimumVersion: 1)))
        #expect(client.handle(failure) == .close)
        #expect(client.phase == .updateRequired(macIsOlder: true))
    }

    @Test("Optimistic volume clamps and unmutes")
    func optimisticVolume() throws {
        var client = helloSent()
        _ = client.handle(try fixture("mac_hello_ack", as: MacFrame.self))
        _ = client.handle(MacFrame(id: 3, message: .state(MacState(volume: 0.2, muted: true, volumeSettable: true,
                                                                  outputName: "Speakers", mediaKeysAllowed: true))))
        client.applyLocalVolume(1.4)
        #expect(client.state?.volume == 1)
        #expect(client.state?.muted == false)
        client.applyLocalMute(true)
        #expect(client.state?.muted == true)
        client.applyLocalVolume(0)
        #expect(client.state?.muted == true)
    }

    @Test("A late hello_ack is ignored")
    func lateHelloAck() throws {
        var client = helloSent()
        _ = client.handle(try fixture("mac_hello_ack", as: MacFrame.self))
        #expect(client.handle(try fixture("mac_hello_ack", as: MacFrame.self)) == .none)
    }

    @Test("pong changes nothing")
    func pong() {
        var client = helloSent()
        #expect(client.handle(MacFrame(id: 9, message: .pong)) == .none)
        #expect(client.phase == .awaitingHelloAck)
    }
}

@Suite("Contract: both sides talking")
struct ConversationTests {
    @Test("A full session through the wire codec keeps both sides in agreement")
    func conversation() throws {
        var mac = MacSessionLogic()
        var client = ClientSessionLogic()
        var macState = MacState(volume: 0.3, muted: false, volumeSettable: true, outputName: "Speakers", mediaKeysAllowed: true)
        var macNextID: UInt32 = 1
        var clientNextID: UInt32 = 1
        var pressed: [MediaCommand] = []

        func execute(_ message: ClientMessage) -> ErrorCode? {
            switch message {
            case .command(let c): pressed.append(c)
            case .setVolume(let v): macState.volume = v
            case .setMuted(let m): macState.muted = m
            default: break
            }
            return nil
        }

        func deliverToMac(_ message: ClientMessage) throws {
            var reader = FrameCodec.Reader()
            reader.append(try FrameCodec.encode(ClientFrame(id: clientNextID, message: message)))
            clientNextID += 1
            let frame = try #require(try reader.next(ClientFrame.self))
            for action in mac.handle(frame, identity: identity, execute: execute) {
                let reply: MacMessage? = switch action {
                case .send(let m): m
                case .sendState, .sendStateNow: .state(macState)
                default: nil
                }
                guard let reply else { continue }
                var back = FrameCodec.Reader()
                back.append(try FrameCodec.encode(MacFrame(id: macNextID, message: reply)))
                macNextID += 1
                _ = client.handle(try #require(try back.next(MacFrame.self)))
            }
        }

        try deliverToMac(client.hello(id: clientNextID, deviceID: phoneID, deviceName: "Matt's iPhone", appVersion: "1.0"))
        #expect(client.isConnected)
        #expect(client.state == macState)

        client.applyLocalVolume(0.75)
        try deliverToMac(.setVolume(0.75))
        try deliverToMac(.command(.playPause))
        try deliverToMac(.command(.next))
        try deliverToMac(.setMuted(true))

        #expect(pressed == [.playPause, .next])
        #expect(macState.volume == 0.75)
        #expect(client.state == macState)
        #expect(client.state?.muted == true)
        #expect(client.lastFailure == nil)
    }
}
