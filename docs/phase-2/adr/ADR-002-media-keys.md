# ADR-002 Play/pause and skip by posting media key events

Status: proposed at G2.

## Context

C5 forbids the private MediaRemote framework, which macOS 15.4 restricted for third-party apps. The primary use case is YouTube in Safari, which per-app AppleScript cannot control reliably (P0.1).

## Decision

The Mac app posts the same system-defined events as the hardware media keys: `NSEvent.otherEvent(with: .systemDefined, …, subtype: 8, data1: (keyCode << 16) | (state << 8))` for key down then key up, with `NX_KEYTYPE_PLAY`, `NX_KEYTYPE_NEXT` and `NX_KEYTYPE_PREVIOUS`, posted through `CGEvent.post(tap: .cghidEventTap)`.

## Consequences

1. Requires Accessibility permission (`AXIsProcessTrusted`). That is why the Mac app ships outside the Mac App Store (C2).
2. macOS routes the key to the current Now Playing app. Auvel cannot choose the target or read play state (F5, F6). The UI is designed around this.
3. Works with any app that supports hardware media keys, including Safari, Chrome, Music and Spotify. T6 confirms on hardware.
