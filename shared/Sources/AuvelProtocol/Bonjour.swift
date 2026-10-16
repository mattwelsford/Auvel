/// Bonjour service details. See docs/phase-2/protocol.md §2.
public enum Bonjour {
    /// Service type advertised by the Mac companion. Also listed in each app's `NSBonjourServices`.
    public static let serviceType = "_auvel._tcp"

    /// Pairing service type. Advertised only while the Mac's pairing window is open.
    public static let pairingServiceType = "_auvel-pair._tcp"

    /// Keys in the service's TXT record.
    public enum TXTKey {
        /// Highest protocol version the Mac supports, as a decimal string.
        public static let protocolVersion = "v"
        /// Stable random identifier for this Mac install. Survives renames and IP changes.
        public static let macID = "id"
        /// Hardware model identifier, for example "Mac15,3". Used only to pick an icon.
        public static let model = "model"
    }
}
