import Foundation
import Testing
@testable import AuvelTransport

@Suite("Pairing Keychain", .serialized)
struct PairingKeychainTests {
    /// A service name unique to this run, so tests never touch real pairings.
    private let keychain = PairingKeychain(service: "nz.co.touchbase.auvel.tests.\(UUID().uuidString)")

    @Test("Save, read back, update and remove")
    func roundTrip() throws {
        defer { for p in (try? keychain.all()) ?? [] { try? keychain.remove(peerID: p.peerID) } }
        #expect(try keychain.all().isEmpty)

        let first = StoredPairing(peerID: UUID(), peerName: "Matt's MacBook Pro", key: Data(repeating: 1, count: 32),
                                  pairedAt: Date(timeIntervalSince1970: 100))
        let second = StoredPairing(peerID: UUID(), peerName: "Studio Mac mini", key: Data(repeating: 2, count: 32),
                                   pairedAt: Date(timeIntervalSince1970: 200))
        try keychain.save(first)
        try keychain.save(second)
        #expect(try keychain.all() == [first, second])

        var renamed = first
        renamed.peerName = "Office"
        try keychain.save(renamed)
        #expect(try keychain.all().first?.peerName == "Office")
        #expect(try keychain.all().count == 2)

        try keychain.remove(peerID: first.peerID)
        #expect(try keychain.all() == [second])
        try keychain.remove(peerID: first.peerID)
    }
}
