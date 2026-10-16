import AuvelProtocol
import AuvelSession
import AuvelTransport
import Foundation
import Network
import Testing
@testable import AuvelTestSupport

// End to end over real loopback sockets: pairing, then a control session, against the mock Mac (T5).
// The same server backs the iPhone UI tests (T3).

private let phoneID = UUID(uuidString: "6F1C2A54-3B7E-4C1D-9A0B-2E5F8D7C6B4A")!

private func endpoint(_ port: NWEndpoint.Port?) throws -> NWEndpoint {
    .hostPort(host: "127.0.0.1", port: try #require(port))
}

/// Runs the iPhone side of pairing against `server`. Returns the key, or the error.
private func pair(with server: MockMacServer, code: UInt32) async throws -> Result<PairingResult, PairingError> {
    var machine = PairingClient(passkey: Passkey(code)!, deviceID: phoneID, deviceName: "Test iPhone")
    let first = machine.start()
    let connection = FramedConnection<PairFrame>(to: try endpoint(server.pairingPort), using: TransportParameters.pairing())
    connection.start()
    defer { connection.cancel() }
    for await event in connection.events {
        switch event {
        case .ready:
            connection.send(first)
        case .frame(let frame):
            do {
                let (send, result) = try machine.receive(frame)
                for outgoing in send { connection.send(outgoing) }
                if let result { return .success(result) }
            } catch {
                if !error.fromPeer { connection.send(machine.failureFrame(error.reason)) }
                return .failure(error)
            }
        case .closed:
            return .failure(PairingError(reason: .protocolError, fromPeer: false))
        }
    }
    return .failure(PairingError(reason: .protocolError, fromPeer: false))
}

/// A connected iPhone-side control session, driven by the shared ClientSessionLogic.
private actor TestClient {
    private let connection: FramedConnection<MacFrame>
    private var logic = ClientSessionLogic()
    private var nextID: UInt32 = 1
    private var waiters: [(@Sendable (ClientSessionLogic) -> Bool, CheckedContinuation<Void, Never>)] = []

    init(port: NWEndpoint.Port, key: Data) {
        connection = FramedConnection<MacFrame>(
            to: .hostPort(host: "127.0.0.1", port: port),
            using: TransportParameters.control(keys: [PreSharedKey(deviceID: phoneID, key: key)])
        )
    }

    func start() {
        connection.start()
        let connection = connection
        Task {
            for await event in connection.events {
                await self.receive(event)
            }
        }
    }

    private func receive(_ event: FramedConnection<MacFrame>.Event) {
        switch event {
        case .ready:
            send(logic.hello(id: nextID, deviceID: phoneID, deviceName: "Test iPhone", appVersion: "1.0"))
        case .frame(let frame):
            _ = logic.handle(frame)
        case .closed:
            break
        }
        let ready = waiters.filter { $0.0(logic) }
        waiters.removeAll { $0.0(logic) }
        for (_, continuation) in ready { continuation.resume() }
    }

    func send(_ message: ClientMessage) {
        connection.send(ClientFrame(id: nextID, message: message))
        nextID += 1
    }

    /// Waits until `condition` holds, up to 5 s. Returns whether it held.
    func wait(until condition: @escaping @Sendable (ClientSessionLogic) -> Bool) async -> Bool {
        if condition(logic) { return true }
        let deadline = Task {
            try? await Task.sleep(for: .seconds(5))
            self.timeout()
        }
        await withCheckedContinuation { waiters.append((condition, $0)) }
        deadline.cancel()
        return condition(logic)
    }

    private func timeout() {
        for (_, continuation) in waiters { continuation.resume() }
        waiters.removeAll()
    }

    func cancel() { connection.cancel() }
}

@Suite("Mock Mac end to end", .serialized)
struct MockMacServerTests {
    @Test("Pair with the right code, then control the Mac")
    func pairAndControl() async throws {
        let server = MockMacServer()
        try await server.start()
        defer { server.stop() }

        let pairing = try await pair(with: server, code: 123_456).get()
        #expect(pairing.peerName == "Mock Mac")
        #expect(pairing.keyData.count == 32)

        // The mock restarts its control listener with the new key. Give it a moment.
        try await Task.sleep(for: .milliseconds(300))
        let client = TestClient(port: try #require(server.controlPort), key: pairing.keyData)
        await client.start()
        #expect(await client.wait { $0.isConnected && $0.state != nil })

        await client.send(.command(.playPause))
        await client.send(.setVolume(0.8))
        await client.send(.setMuted(true))
        #expect(await client.wait { $0.state?.muted == true })
        #expect(server.receivedCommands == [.command(.playPause), .setVolume(0.8), .setMuted(true)])
        #expect(server.state.volume == 0.8)

        // A change made on the Mac reaches the iPhone.
        server.updateState { $0.volume = 0.25 }
        #expect(await client.wait { $0.state?.volume == 0.25 })
        await client.cancel()
    }

    @Test("A wrong code is refused and gives no key")
    func wrongCode() async throws {
        let server = MockMacServer()
        try await server.start()
        defer { server.stop() }
        let result = try await pair(with: server, code: 654_321)
        #expect(throws: PairingError.self) { try result.get() }
        #expect(server.pairedDeviceIDs.isEmpty)
    }

    @Test("Without pairing, the control listener refuses the TLS handshake")
    func unpairedClientRefused() async throws {
        let server = MockMacServer()
        try await server.start()
        defer { server.stop() }
        let client = TestClient(port: try #require(server.controlPort), key: Data(repeating: 7, count: 32))
        await client.start()
        #expect(!(await client.wait { $0.isConnected }))
        #expect(server.receivedCommands.isEmpty)
    }

    @Test("Commands fail with the right codes when the Mac cannot perform them")
    func failures() async throws {
        let server = MockMacServer(.init(initialState: MacState(volume: 0, muted: false, volumeSettable: false,
                                                                outputName: "LG UltraFine", mediaKeysAllowed: false)))
        try await server.start()
        defer { server.stop() }
        let key = try await pair(with: server, code: 123_456).get().keyData
        try await Task.sleep(for: .milliseconds(300))
        let client = TestClient(port: try #require(server.controlPort), key: key)
        await client.start()
        #expect(await client.wait { $0.isConnected })
        await client.send(.command(.next))
        #expect(await client.wait { $0.lastFailure == .mediaKeysNotAllowed })
        await client.send(.setVolume(0.5))
        #expect(await client.wait { $0.lastFailure == .volumeNotSettable })
        await client.cancel()
    }
}
