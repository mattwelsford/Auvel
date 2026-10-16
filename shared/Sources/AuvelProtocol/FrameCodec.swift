import Foundation

/// Length-prefixed JSON framing. See docs/phase-2/protocol.md §3.
///
/// Each frame is a 4-byte big-endian payload length followed by that many bytes of UTF-8 JSON.
public enum FrameCodec {
    /// Largest accepted payload. Version 1 messages are far below this.
    public static let maxPayloadLength = 16 * 1024

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = try encoder.encode(value)
        guard payload.count <= maxPayloadLength else { throw ProtocolError.frameTooLarge(payload.count) }
        var length = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(payload)
        return frame
    }

    /// Collects bytes from a stream and returns whole frames as they complete.
    public struct Reader: Sendable {
        private var buffer = Data()

        public init() {}

        public mutating func append(_ data: Data) {
            buffer.append(data)
        }

        /// Returns the next complete frame, or `nil` if more bytes are needed.
        /// Throws `frameTooLarge` as soon as a length prefix exceeds the limit, so a peer
        /// cannot make the reader buffer unbounded data.
        public mutating func next<T: Decodable>(_ type: T.Type) throws -> T? {
            guard buffer.count >= 4 else { return nil }
            let length = buffer.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard length <= FrameCodec.maxPayloadLength else { throw ProtocolError.frameTooLarge(length) }
            guard buffer.count >= 4 + length else { return nil }
            let payload = buffer.dropFirst(4).prefix(length)
            buffer = Data(buffer.dropFirst(4 + length))
            return try JSONDecoder().decode(T.self, from: Data(payload))
        }
    }
}
