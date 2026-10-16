/// Protocol version numbers and negotiation. See docs/phase-2/protocol.md §4.
public enum ProtocolVersion {
    /// Version of the frame envelope (`v` field). Changes only if the envelope itself changes.
    public static let wire = 1

    /// Message-set versions this build can speak, newest last.
    public static let supported: [Int] = [1]

    /// The version this build prefers.
    public static var current: Int { supported.last! }

    /// Picks the highest version both sides support, or `nil` if there is none.
    public static func negotiate(client: [Int], server: [Int]) -> Int? {
        Set(client).intersection(server).max()
    }
}
