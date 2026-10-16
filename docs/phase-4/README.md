# Phase 4 testing · G4 review packet

Status: automated tests built and running in CI. **Outstanding:** snapshot reference images (Q12), and the manual T6 and T7 checklists, which need Matt and real devices.

## Test plan status

| Code | Requirement | Status | Evidence |
|---|---|---|---|
| T1 | Unit tests with at least 80% line coverage of shared code | **Met.** 95.96% of lines, 64 tests in 13 suites | CI job "Shared package", step "Coverage report". The table is also in the run summary and the `shared-coverage` artifact. |
| T2 | Protocol contract tests both sides run against | **Met.** Every fixture in `shared/Tests/AuvelProtocolTests/Fixtures` has a contract case, driven through `MacSessionLogic` and `ClientSessionLogic` | `shared/Tests/AuvelSessionTests/ContractTests.swift` |
| T3 | UI tests for pairing, control and reconnect | **Met.** All three pass in CI run 22, against the mock Mac found over Bonjour. Stability over more runs is still to be shown (F24). | `ios/Tests/UI/RemoteFlowUITests.swift` |
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
5. **F24 UI test timing.** Run 20 showed two test races. The reconnect test could tap Play before the app had noticed the dropped connection, so it now retries until the command arrives. Run 21 showed the same race in the control test: the remote appears before the session connects, so the test now waits for Play to be enabled. Bonjour discovery on a freshly booted simulator once took longer than 15 s, so the timeout is now 30 s. If discovery still flakes, the fallback is a debug-only launch argument that hands the app the mock's address directly.
6. **F23 CI artifacts unreachable from the build session.** The session's network blocks GitHub's artifact storage (`*.blob.core.windows.net`). Snapshots recorded on the runner cannot be pulled back. See Q12.

## Decision log

| Code | Decision |
|---|---|
| Q12 | O1. Matt allows `*.blob.core.windows.net` so the session can pull the `ios-snapshots` artifact and commit it. |
| Q13 | Yes. T6 and T7 are filled in during the G3 hardware session, on the same devices. |
