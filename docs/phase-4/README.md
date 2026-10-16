# Phase 4 testing · G4 review packet

Status: automated tests built and running in CI. **Outstanding:** snapshot reference images (Q12), and the manual T6 and T7 checklists, which need Matt and real devices.

## Test plan status

| Code | Requirement | Status | Evidence |
|---|---|---|---|
| T1 | Unit tests with at least 80% line coverage of shared code | **Met.** 95.96% of lines, 64 tests in 13 suites | CI job "Shared package", step "Coverage report". The table is also in the run summary and the `shared-coverage` artifact. |
| T2 | Protocol contract tests both sides run against | **Met.** Every fixture in `shared/Tests/AuvelProtocolTests/Fixtures` has a contract case, driven through `MacSessionLogic` and `ClientSessionLogic` | `shared/Tests/AuvelSessionTests/ContractTests.swift` |
| T3 | UI tests for pairing, control and reconnect | Built. Pairing and reconnect pass in CI. Control is being fixed (F21). | `ios/Tests/UI/RemoteFlowUITests.swift` |
| T4 | Snapshot tests of key screens, light, dark and AX5 | Built. 9 screens × 3 variants = 27 images recorded in CI. **Blocked on Q12** before they can be committed and compared. | `ios/Tests/Unit/SnapshotTests.swift` |
| T5 | Mock Mac server for tests without hardware | **Met.** Pairing listener, TLS-PSK control listener, Bonjour advertising, scripted state and failures | `shared/Sources/AuvelTestSupport/MockMacServer.swift`, `shared/Tests/AuvelTestSupportTests/MockMacServerTests.swift` |
| T6 | Manual hardware matrix | Checklist ready, needs Matt | [T6-hardware-matrix.md](T6-hardware-matrix.md) |
| T7 | VoiceOver and Accessibility Inspector audit | Checklist ready, needs Matt | [T7-accessibility-audit.md](T7-accessibility-audit.md) |
| T8 | CI runs every test on every push and pull request | **Met.** `.github/workflows/ci.yml` triggers on `push` and `pull_request` and runs the shared tests, both app builds and the iPhone tests | `.github/workflows/ci.yml` |

## How to run locally

1. Shared: `swift test --package-path shared --enable-code-coverage`
2. iPhone: `cd ios && xcodegen generate`, then run the Auvel scheme's tests in Xcode, or `xcodebuild test -project Auvel.xcodeproj -scheme Auvel -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
3. Re-record snapshots after an intended design change: set `RECORD_SNAPSHOTS=1` in the scheme's test environment and run once.

## Findings

1. **F19 Keychain listing failed on macOS.** `PairingKeychain.all()` asked for every item's data in one query. The macOS file-based keychain rejects that with `errSecParam` (-50), so the Mac app could not read its pairings. The new Keychain test caught it. Fixed: list accounts, then read each item. **Affects G3:** test with a build from commit `6e9227f` or later, or H-checks that rely on remembered iPhones will fail.
2. **F20 Mock server test race.** The test client's 5 s timeout fired early when an earlier wait was cancelled. Test-only bug, fixed.
3. **F21 Mute is a switch to XCUITest.** Mute carries the toggle trait (T7 V5), so UI tests find it under `switches`, not `buttons`. Test updated. Volume uses a vertical swipe on the dial, because XCUITest cannot send an adjustable increment on iOS.
4. **F22 Coverage includes the mock server.** `AuvelTestSupport` is shared source, so it counts toward T1. Without it, coverage is 786 lines with 25 missed: 96.8%. The gate passes either way.
5. **F23 CI artifacts unreachable from the build session.** The session's network blocks GitHub's artifact storage (`*.blob.core.windows.net`). Snapshots recorded on the runner cannot be pulled back. See Q12.

## Questions

1. **Q12** How should the 27 recorded snapshot images reach the repository?
   - **O1 (recommended):** allow `*.blob.core.windows.net` in the environment's network settings. I download the `ios-snapshots` artifact and commit it.
   - **O2:** download `ios-snapshots` from the latest CI run and commit the contents to `ios/Tests/Unit/__Snapshots__/`.
   - **O3:** give the iPhone tests job `contents: write`, so CI pushes recorded images to a `ci/snapshots-*` branch.
2. **Q13** Fill in T6 and T7 alongside the G3 hardware recording? Both use the same devices.
