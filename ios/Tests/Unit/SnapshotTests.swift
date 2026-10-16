import AuvelProtocol
import AuvelTransport
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Auvel

/// T4: key screens in light, dark and the largest accessibility text size.
/// Reference images live in __Snapshots__ next to this file. Record new ones with RECORD_SNAPSHOTS=1.
@MainActor
final class SnapshotTests: XCTestCase {
    /// iPhone 16 Pro logical size, matching the G1 renders.
    private static let size = CGSize(width: 402, height: 874)
    private static let safeArea = UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)

    private enum Variant: String, CaseIterable {
        case light, dark, ax5

        var traits: UITraitCollection {
            switch self {
            case .light: UITraitCollection(userInterfaceStyle: .light)
            case .dark: UITraitCollection(userInterfaceStyle: .dark)
            case .ax5: UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: .light),
                UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            ])
            }
        }

        var dynamicType: DynamicTypeSize { self == .ax5 ? .accessibility5 : .large }
        var scheme: ColorScheme { self == .dark ? .dark : .light }
    }

    private let mac = StoredPairing(peerID: UUID(uuidString: "0C2D9E1F-7A4B-4E3C-8B5A-1D2E3F4A5B6C")!,
                                    peerName: "Matt's MacBook Pro", key: Data(count: 32), pairedAt: Date(timeIntervalSince1970: 0))
    private lazy var model = AppModel()

    nonisolated override func invokeTest() {
        withSnapshotTesting(record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing) {
            super.invokeTest()
        }
    }

    private func snapshot<V: View>(_ view: V, named name: String, file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        for variant in Variant.allCases {
            let root = view
                .environment(model)
                .environment(\.dynamicTypeSize, variant.dynamicType)
                .environment(\.colorScheme, variant.scheme)
                .tint(.goldText)
            let controller = UIHostingController(rootView: root)
            controller.overrideUserInterfaceStyle = variant.scheme == .dark ? .dark : .light
            assertSnapshot(
                of: controller,
                as: .image(on: ViewImageConfig(safeArea: Self.safeArea, size: Self.size, traits: variant.traits), precision: 0.99),
                named: "\(name)-\(variant.rawValue)",
                file: file, testName: testName, line: line
            )
        }
    }

    private func state(volume: Double = 0.62, muted: Bool = false, settable: Bool = true, keys: Bool = true) -> MacState {
        MacState(volume: volume, muted: muted, volumeSettable: settable, outputName: settable ? "MacBook Pro Speakers" : "LG UltraFine", mediaKeysAllowed: keys)
    }

    // MARK: Remote (I08 to I13, I19)

    func testRemoteConnected() {
        snapshot(RemoteView(session: .preview(mac: mac, status: .connected, state: state())), named: "I08")
    }

    func testRemoteMuted() {
        snapshot(RemoteView(session: .preview(mac: mac, status: .connected, state: state(muted: true))), named: "I09")
    }

    func testRemoteVolumeNotAdjustable() {
        snapshot(RemoteView(session: .preview(mac: mac, status: .connected, state: state(settable: false))), named: "I10")
    }

    func testRemoteAccessibilityMissing() {
        snapshot(RemoteView(session: .preview(mac: mac, status: .connected, state: state(keys: false))), named: "I11")
    }

    func testRemoteUnreachable() {
        snapshot(RemoteView(session: .preview(mac: mac, status: .unreachable, state: nil)), named: "I12")
    }

    func testRemoteUpdateRequired() {
        snapshot(RemoteView(session: .preview(mac: mac, status: .updateRequired(macIsOlder: true), state: nil)), named: "I13")
    }

    // MARK: Onboarding and settings

    func testOnboarding() {
        snapshot(OnboardingView(), named: "I01")
    }

    func testSettings() {
        snapshot(SettingsView(), named: "I16")
    }

    func testTroubleshooting() {
        snapshot(NavigationStack { TroubleshootingView() }, named: "I18")
    }
}
