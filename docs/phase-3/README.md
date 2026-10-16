# Phase 3 build · G3 review packet

Status: code complete and building in CI. **G3 evidence (hardware recording) is outstanding** and needs Matt: see [hardware-test.md](hardware-test.md).

## What was built

| Area | Contents |
|---|---|
| `shared/AuvelProtocol` | Control and pairing messages, framing, version negotiation, pairing state machines (protocol §6) |
| `shared/AuvelTransport` | TLS-PSK and pairing `NWParameters`, framed connections, Keychain store for pairing keys |
| `mac/` | Media keys, CoreAudio volume and mute, Accessibility polling, control server with Bonjour, pairing host, login item, Sparkle, menu (M01, M02), welcome (M03, M04), pairing (M05, M06), paired iPhones list |
| `ios/` | Discovery, pairing flow, remote session with reconnect and throttled volume, Direction B dial, I01 to I21 states, Mac picker, settings, troubleshooting, haptics, Liquid Glass surfaces on iOS 26 |

## Evidence available now

| Item | Result |
|---|---|
| CI | All three jobs green on the latest commit. Link in the G3 summary. |
| Shared tests | 36 tests in 7 suites pass, including pairing and loopback TLS tests |
| P3-verify, protocol §7.3 | **Resolved.** A listener holding two keys accepts each iPhone with its own key. Wrong key fails with TLS error -9820, unknown identity with -9864. |
| P3-verify, protocol §7.2 | **Resolved: not available.** TLS 1.3 with an external PSK fails on macOS 26 (TLS error -9858). Auvel uses TLS 1.2 PSK. R13 stays open as an accepted low risk. |

## Evidence outstanding (needs hardware)

1. Screen recording R1 to R8 in [hardware-test.md](hardware-test.md).
2. Checks H1 to H14, which also confirm items that cannot run in CI: media key routing, `pmset sleepnow`, the macOS Local Network prompt, Local Network denial detection on iOS, and Keychain on a signed Mac build.

## Findings from the build

1. **F15 iPhone name.** Since iOS 16, `UIDevice.name` returns "iPhone" unless the app has Apple's user-assigned device name entitlement, which requires a request to Apple. The Mac will list "iPhone" rather than "Matt's iPhone". Options: request the entitlement before launch (recommended, needs Matt's developer account) or let the user name the iPhone in Settings.
2. **F16 Menu bar badge.** M01 showed a green dot on the menu bar icon while an iPhone is connected. A template menu bar image cannot carry a coloured dot. Built instead: the attention variant of the icon (warning triangle) when Accessibility or Local Network is missing, and the connected count in the accessibility label and the menu.
3. **F17 Mac model icons.** Apple silicon Macs report model identifiers like "Mac15,3" that do not say laptop or desktop. The iPhone falls back to the laptop symbol. Logged as backlog B8.
4. **F18 Copyright holder.** `LICENSE` names Matt Welsford. Bundle IDs now use Touchbase (Q8). See Q9.

## Questions

1. **Q9** Should the copyright holder in `LICENSE` and the About box be Matt Welsford or Touchbase?
2. **Q10** Is the Apple Developer Program membership individual or organisation? The App Store seller name and the Developer ID shown by Gatekeeper both come from it. To show "Touchbase", the membership must be an organisation account, which needs a D-U-N-S number.
3. **Q11** F15: request the device name entitlement from Apple, or add a name field in Settings?
