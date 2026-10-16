import AuvelProtocol
import Foundation
import Network
import Testing
@testable import AuvelTransport

// Real TLS-PSK handshakes over loopback. These answer the P3-verify items in protocol §7.

private enum Outcome: Equatable, Sendable {
    case pong
    case closed(CloseReason)
    case timeout
}

private let phoneA = UUID(uuidString: "6F1C2A54-3B7E-4C1D-9A0B-2E5F8D7C6B4A")!
private let phoneB = UUID(uuidString: "A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF")!
private func key(_ byte: UInt8) -> Data { Data(repeating: byte, count: 32) }

/// Starts a listener holding `serverKeys`, connects with `clientKey`, sends `ping` and reports what came back.
private func exchangePing(serverKeys: [PreSharedKey], clientKey: PreSharedKey,
                          tls: tls_protocol_version_t = .TLSv12) async throws -> Outcome {
    let listener = try NWListener(using: TransportParameters.control(keys: serverKeys, tlsVersion: tls), on: .any)
    listener.newConnectionHandler = { nw in
        let server = FramedConnection<ClientFrame>(connection: nw)
        Task {
            for await event in server.events {
                if case .frame(let frame) = event, frame.message == .ping {
                    server.send(MacFrame(id: 1, message: .pong))
                }
            }
        }
        server.start()
    }
    let port: NWEndpoint.Port = try await withCheckedThrowingContinuation { continuation in
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                listener.stateUpdateHandler = nil
                continuation.resume(returning: listener.port!)
            case .failed(let error):
                listener.stateUpdateHandler = nil
                continuation.resume(throwing: error)
            default:
                break
            }
        }
        listener.start(queue: DispatchQueue(label: "test.listener"))
    }
    defer { listener.cancel() }

    let client = FramedConnection<MacFrame>(
        to: .hostPort(host: "127.0.0.1", port: port),
        using: TransportParameters.control(keys: [clientKey], tlsVersion: tls)
    )
    client.start()
    defer { client.cancel() }

    return await withTaskGroup(of: Outcome.self) { group in
        group.addTask {
            for await event in client.events {
                switch event {
                case .ready:
                    client.send(ClientFrame(id: 1, message: .ping))
                case .frame(let frame):
                    if frame.message == .pong { return .pong }
                case .closed(let reason):
                    return .closed(reason)
                }
            }
            return .timeout
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(5))
            return .timeout
        }
        let first = await group.next() ?? .timeout
        group.cancelAll()
        return first
    }
}

@Suite("Loopback TLS-PSK", .serialized)
struct LoopbackTests {
    @Test("Matching key: handshake succeeds and frames flow")
    func matchingKey() async throws {
        let psk = PreSharedKey(deviceID: phoneA, key: key(1))
        #expect(try await exchangePing(serverKeys: [psk], clientKey: psk) == .pong)
    }

    @Test("Wrong key: no frames are exchanged")
    func wrongKey() async throws {
        let outcome = try await exchangePing(serverKeys: [PreSharedKey(deviceID: phoneA, key: key(1))],
                                             clientKey: PreSharedKey(deviceID: phoneA, key: key(2)))
        #expect(outcome != .pong)
        print("Wrong-key outcome: \(outcome)")
    }

    @Test("Unknown identity: no frames are exchanged")
    func unknownIdentity() async throws {
        let outcome = try await exchangePing(serverKeys: [PreSharedKey(deviceID: phoneA, key: key(1))],
                                             clientKey: PreSharedKey(deviceID: phoneB, key: key(1)))
        #expect(outcome != .pong)
        print("Unknown-identity outcome: \(outcome)")
    }

    @Test("Mac holding two keys selects the right one by identity (protocol §7.3)")
    func selectsByIdentity() async throws {
        let a = PreSharedKey(deviceID: phoneA, key: key(1))
        let b = PreSharedKey(deviceID: phoneB, key: key(2))
        #expect(try await exchangePing(serverKeys: [a, b], clientKey: a) == .pong)
        #expect(try await exchangePing(serverKeys: [a, b], clientKey: b) == .pong)
    }

    @Test("TLS 1.3 with PSK (protocol §7.2, informational)")
    func tls13() async throws {
        let psk = PreSharedKey(deviceID: phoneA, key: key(1))
        let outcome = try await exchangePing(serverKeys: [psk], clientKey: psk, tls: .TLSv13)
        print("TLS 1.3 PSK outcome: \(outcome)")
        withKnownIssue("TLS 1.3 external PSK support in Network.framework is unconfirmed", isIntermittent: true) {
            #expect(outcome == .pong)
        }
    }
}
