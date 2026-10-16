import AppKit
import ApplicationServices

/// Posts hardware media key events (ADR-002). Requires Accessibility permission.
enum MediaKeys {
    /// Key codes from IOKit `ev_keymap.h`. Apple keyboards send FAST and REWIND for the ⏭ and ⏮ keys.
    enum Key: Int {
        case playPause = 16 // NX_KEYTYPE_PLAY
        case next = 19 // NX_KEYTYPE_FAST
        case previous = 20 // NX_KEYTYPE_REWIND
    }

    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Sends key down then key up. Returns false if Accessibility is not granted.
    @discardableResult
    static func press(_ key: Key) -> Bool {
        guard isAllowed else { return false }
        for down in [true, false] {
            let state = down ? 0xA : 0xB
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: (key.rawValue << 16) | (state << 8),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        return true
    }
}
