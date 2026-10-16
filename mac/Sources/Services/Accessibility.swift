import AppKit
import ApplicationServices

/// Accessibility permission state (M03). macOS has no change notification, so the app polls.
enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Adds Auvel to the Accessibility list so the user only has to flip the switch.
    static func registerWithSystem() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: false] as CFDictionary)
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func openLocalNetworkSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")!
        NSWorkspace.shared.open(url)
    }
}
