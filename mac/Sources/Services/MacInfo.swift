import Foundation

/// Identity this Mac advertises (protocol §2).
enum MacInfo {
    private static let idKey = "macID"

    /// Random per-install identifier, created on first launch.
    static var id: UUID {
        if let stored = UserDefaults.standard.string(forKey: idKey), let id = UUID(uuidString: stored) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
        return id
    }

    static var name: String {
        Host.current().localizedName ?? "Mac"
    }

    /// Hardware model identifier, for example "Mac15,3".
    static var model: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
