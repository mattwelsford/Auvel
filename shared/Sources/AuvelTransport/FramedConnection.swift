import AuvelProtocol
import Foundation
import Network

public enum CloseReason: Equatable, Sendable {
    case cancelled
    case peerClosed
    /// TLS handshake or record failure. With PSK this usually means the peer does not hold our key.
    case tls(OSStatus)
    case network(String)
    /// The peer sent an oversized, malformed or unknown frame.
    case protocolViolation(String)
}

/// A Network.framework connection that sends and receives length-prefixed JSON frames (protocol §3).
///
/// All mutable state is confined to `queue`, which is also the queue Network.framework calls back on.
public final class FramedConnection<Inbound: Decodable & Sendable>: @unchecked Sendable {
    public enum Event: Sendable {
        case ready
        case frame(Inbound)
        case closed(CloseReason)
    }

    public let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "auvel.framed-connection")
    private var reader = FrameCodec.Reader()
    private var finished = false

    public init(connection: NWConnection) {
        self.connection = connection
        (events, continuation) = AsyncStream.makeStream(of: Event.self)
    }

    public convenience init(to endpoint: NWEndpoint, using parameters: NWParameters) {
        self.init(connection: NWConnection(to: endpoint, using: parameters))
    }

    public var endpoint: NWEndpoint { connection.endpoint }

    public func start() {
        connection.stateUpdateHandler = { [weak self] state in self?.handle(state) }
        connection.start(queue: queue)
    }

    public func send<Outbound: Encodable>(_ frame: Outbound) {
        let data: Data
        do {
            data = try FrameCodec.encode(frame)
        } catch {
            assertionFailure("Frame could not be encoded: \(error)")
            return
        }
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error { self?.finish(Self.reason(for: error)) }
        })
    }

    public func cancel() {
        queue.async { self.finish(.cancelled) }
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            continuation.yield(.ready)
            receive()
        case .failed(let error):
            finish(Self.reason(for: error))
        case .waiting(let error):
            // A rejected TLS handshake leaves the connection waiting to retry. Treat it as final.
            if case .tls = error { finish(Self.reason(for: error)) }
        case .cancelled:
            finish(.cancelled)
        default:
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                reader.append(data)
                do {
                    while let frame = try reader.next(Inbound.self) {
                        continuation.yield(.frame(frame))
                    }
                } catch {
                    finish(.protocolViolation(String(describing: error)))
                    return
                }
            }
            if let error {
                finish(Self.reason(for: error))
            } else if isComplete {
                finish(.peerClosed)
            } else {
                receive()
            }
        }
    }

    private func finish(_ reason: CloseReason) {
        guard !finished else { return }
        finished = true
        continuation.yield(.closed(reason))
        continuation.finish()
        connection.cancel()
    }

    static func reason(for error: NWError) -> CloseReason {
        if case .tls(let status) = error { return .tls(status) }
        return .network(error.debugDescription)
    }
}
