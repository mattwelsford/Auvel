import Foundation
import Sparkle

/// Sparkle 2 auto-update (ADR-006). Starts only when the build carries a public EdDSA key,
/// so development and CI builds never show Sparkle errors.
@MainActor
final class Updater {
    private let controller: SPUStandardUpdaterController?

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        controller = key.isEmpty ? nil : SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
