import Foundation
import Security

/// A paired peer as stored on this device. The key never leaves the Keychain except to build TLS parameters.
public struct StoredPairing: Codable, Equatable, Sendable, Identifiable {
    public let peerID: UUID
    public var peerName: String
    public let key: Data
    public let pairedAt: Date

    public var id: UUID { peerID }

    public init(peerID: UUID, peerName: String, key: Data, pairedAt: Date = .now) {
        self.peerID = peerID
        self.peerName = peerName
        self.key = key
        self.pairedAt = pairedAt
    }
}

public enum KeychainError: Error, Equatable {
    case status(OSStatus)
}

/// Pairing keys in the Keychain (threat model §5.4): generic password items, this device only, no iCloud sync.
public struct PairingKeychain: Sendable {
    public let service: String

    public init(service: String) {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: false,
        ]
        #if os(iOS)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        return query
    }

    public func all() throws -> [StoredPairing] {
        // The macOS file-based keychain refuses data with kSecMatchLimitAll (errSecParam),
        // so list the accounts first and read each item's data on its own.
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        let accounts = ((result as? [[String: Any]]) ?? []).compactMap { $0[kSecAttrAccount as String] as? String }
        return try accounts.compactMap { try data(account: $0) }
            .compactMap { try? JSONDecoder().decode(StoredPairing.self, from: $0) }
            .sorted { $0.pairedAt < $1.pairedAt }
    }

    private func data(account: String) throws -> Data? {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        return result as? Data
    }

    public func save(_ pairing: StoredPairing) throws {
        let data = try JSONEncoder().encode(pairing)
        var query = baseQuery
        query[kSecAttrAccount as String] = pairing.peerID.uuidString
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func remove(peerID: UUID) throws {
        var query = baseQuery
        query[kSecAttrAccount as String] = peerID.uuidString
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}
