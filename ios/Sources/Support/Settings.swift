import SwiftUI
import UIKit

/// User settings (I16). Stored with @AppStorage under these keys.
enum SettingKey {
    static let haptics = "haptics"
    static let volumeStep = "volumeStep"
    static let keepAwake = "keepScreenAwake"
}

/// Haptic rules from design system §7. All feedback respects the Haptics setting.
@MainActor
enum Haptics {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingKey.haptics) as? Bool ?? true
    }

    static func command() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func volumeStep() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func volumeLimit() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func mute() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

extension Color {
    static let gold = Color("Gold")
    static let goldText = Color("GoldText")
    static let canvas = Color("Canvas")
}

/// SF Symbol for a Mac model identifier. Apple silicon models all read "MacNN,N", so most fall back to a laptop.
func macSymbol(for model: String) -> String {
    switch true {
    case model.hasPrefix("Macmini"): "macmini"
    case model.hasPrefix("MacStudio"): "macstudio"
    case model.hasPrefix("iMac"): "desktopcomputer"
    case model.hasPrefix("MacPro"): "macpro.gen3"
    default: "laptopcomputer"
    }
}

/// Custom control surfaces (F12): Liquid Glass on iOS 26 and later, the G1 fill on iOS 18 to 25.
struct AuvelSurface<S: Shape>: ViewModifier {
    let shape: S
    var inverted = false

    func body(content: Content) -> some View {
        if inverted {
            content.background(Color(.label), in: shape)
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(.fill.tertiary, in: shape)
        }
    }
}

extension View {
    func auvelSurface<S: Shape>(_ shape: S, inverted: Bool = false) -> some View {
        modifier(AuvelSurface(shape: shape, inverted: inverted))
    }
}
