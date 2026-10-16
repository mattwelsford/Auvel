# ADR-007 Minimum OS versions and toolchain

Status: proposed at G2.

## Decision

| Item | Value | Reason |
|---|---|---|
| iPhone minimum | iOS 18 | Covers the current and previous major release. SwiftUI features used (`ContentUnavailableView`, Observation) need iOS 17+. |
| Mac minimum | macOS 15 | Covers the current and previous major release. `MenuBarExtra` and `SMAppService` need macOS 13+. |
| Build toolchain | Xcode 26, Swift 6 language mode | CI selects the newest stable Xcode on the `macos-26` runner. |
| Tests | Swift Testing | Brief T1. |

## Consequences

1. Built with the iOS 26 and macOS 26 SDKs, system controls, sheets and bars adopt Liquid Glass automatically on iOS 26 and macOS 26. Custom surfaces in the G1 designs (Mac picker chip, round buttons, banners) use `.glassEffect()` on 26 and later and the G1 fill colours on 18 and 25 (F12).
2. T6 tests two macOS and two iOS versions: macOS 15 and 26, iOS 18 and 26.
