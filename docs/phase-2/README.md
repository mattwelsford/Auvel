# Phase 2 architecture · G2 review packet

Status: **G2 approved 2026-10-16.**

## G2 decision log

| Code | Decision |
|---|---|
| D9 | Protocol spec, threat model and ADR-001 to ADR-007 approved. |
| D10 | I06 copy change approved. |
| Q7 | Create `main` from the working branch. Matt sets it as default and adds branch protection. |
| Q8 | Bundle IDs use Matt's company Touchbase: `nz.co.touchbase.auvel` (iPhone) and `nz.co.touchbase.auvel.mac` (Mac), from touchbase.co.nz. |

## G2 evidence

| Item | Where |
|---|---|
| Repo skeleton: `mac/`, `ios/`, `shared/`, `site/` | Repository root, [README](../../README.md) |
| CI building both apps and testing the shared package | [.github/workflows/ci.yml](../../.github/workflows/ci.yml). Run links in the G2 summary. |
| Versioned protocol spec | [protocol.md](protocol.md) |
| Threat model | [threat-model.md](threat-model.md) |
| Decision records | [adr/](adr/) |

## What the skeleton contains

1. `shared/`: the `AuvelKit` Swift package. `AuvelProtocol` implements every protocol §5 message, the envelope, framing with a size cap, and version negotiation. It has 17 Swift Testing tests: fixture decode, byte-exact encode, invalid input and framing. The pairing implementation (§6) is Phase 3 work.
2. `mac/`: a menu bar app with one menu. Hardened runtime, no sandbox, `LSUIElement`, both Bonjour types and the local network usage string.
3. `ios/`: one placeholder screen. App icon with dark and tinted variants, both Bonjour types, the local network usage string, and `ITSAppUsesNonExemptEncryption = NO` (R8).
4. `site/`: one placeholder page. Phase 5 builds the site.
5. MIT `LICENSE` and a short README with build steps.

## Decisions

| Code | Record | Summary |
|---|---|---|
| ADR-001 | [Monorepo, XcodeGen](adr/ADR-001-monorepo-xcodegen.md) | Projects generated from `project.yml`, not committed. |
| ADR-002 | [Media keys](adr/ADR-002-media-keys.md) | Post system-defined media key events. Needs Accessibility. |
| ADR-003 | [Volume](adr/ADR-003-volume-coreaudio.md) | CoreAudio on the default output device. Reports when volume is not settable. |
| ADR-004 | [Transport](adr/ADR-004-transport.md) | Network.framework, two Bonjour services, TLS with a PSK, length-prefixed JSON. |
| ADR-005 | [Pairing](adr/ADR-005-pairing.md) | Bluetooth-style Passkey Entry: 20 commit-reveal rounds over ECDH. |
| ADR-006 | [Distribution](adr/ADR-006-distribution-updates.md) | Developer ID, notarisation, Sparkle 2, project Homebrew tap. |
| ADR-007 | [Platforms](adr/ADR-007-platforms-toolchain.md) | iOS 18+, macOS 15+, Xcode 26, Swift 6, Swift Testing. |

## New findings

1. **F12 Liquid Glass.** iOS 26 and macOS 26 use the Liquid Glass design language. The G1 renders show the earlier style. System controls adopt Liquid Glass automatically when built with the 26 SDKs. Custom surfaces use `.glassEffect()` on 26 and later, and the G1 fills on iOS 18 and macOS 15 (ADR-007). This keeps C7 without redoing G1. P3 screenshots will show the real result.
2. **F13 Pairing copy change.** Secure pairing needs a new code after every failed attempt (ADR-005). I06 changes from "3 tries left" to "That code didn't match. Enter the new code shown on your Mac." The Mac shows the new code at once and closes the pairing window after 3 failures.
3. **F14 No `main` branch.** The repository's only branch, and its default, is `claude/dazzling-lamport-6nwkd9`. The done criteria need "CI green on main".

## New risks

1. **R12 Signing keys** give code-signing power over every user's Accessibility grant. They stay in GitHub encrypted secrets used only by the release workflow (threat model §6).
2. **R13 No forward secrecy** if Network.framework only offers TLS 1.2 PSK. Low impact. Checked in P3.
3. **R14 New pairing code** is security-critical. Outside review recommended before launch.

## Decisions and questions for G2

1. **D9** Approve the protocol spec, threat model and ADR-001 to ADR-007.
2. **D10** Approve the I06 copy change (F13).
3. **Q7** May I create `main` from the current branch? You would then set it as the default branch and add branch protection in the repository settings, because both need your account.
4. **Q8** Bundle IDs are `com.mattwelsford.auvel` (iPhone) and `com.mattwelsford.auvel.mac` (Mac). The iPhone ID is permanent once uploaded to App Store Connect. Keep these, or use another prefix?
