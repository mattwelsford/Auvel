# Phase 0 concept · G0 review packet

Status: ready for review. No production code written.

| Item | Deliverable | State |
|---|---|---|
| P0.1 | [Competitor teardown](P0.1-competitor-teardown.md) | Done. Sources limited to web search (see F4). |
| P0.2 | [Wireframes](P0.2-wireframes.md), 6 iPhone + 3 Mac | Done. |
| P0.3 | [Three directions, light and dark](P0.3-directions.md) | Done. Recommends A. |
| P0.4 | [Journey map](P0.4-journey-map.md), 12 steps, 24 failure points | Done. |
| P0.5 | [Name check and icons](P0.5-name-and-icon.md) | Done. **AUREM fails US clearance (N1).** Icon I1 chosen. |

Rendering note: SF Pro and SF Symbols cannot be used in this Linux environment. Inter and hand-drawn glyphs stand in. P1 high-fidelity work uses the real assets.

## Findings

1. **F1** Rimote (rimote.app) is a free iPhone + Mac remote with the same v1 scope: volume, media, sleep, lock. LAN only, PIN pairing, MIT-licensed Mac agent. Source is its own site, unverified. This challenges the US$4.99 price (R1, Q1).
2. **F2** An App Store app named "Aurem – Customizable Journal App" appears in search results. This contradicts the brief's statement that App Store search is clear. Not confirmed live.
3. **F3** Three other software products use "Aurem": auremapp.com, aurem.tech (AuremOS), aurem.live.
4. **F4** USPTO, IPONZ and domain lookups were blocked by the environment's network policy. No register result exists.
5. **F5** Without MediaRemote (C5) the apps cannot know play state or which app receives the media key. Play/pause is one toggle. The UI never says "Playing".
6. **F6** Media keys go to whichever app macOS considers the current Now Playing app. If Music was last active, the key may start Music instead of pausing YouTube.
7. **F7** CoreAudio cannot set volume on outputs without a software volume control, common on HDMI and DisplayPort displays. The design needs a "volume not adjustable here" state.
8. **F8** Homebrew's main cask repo requires notability: for a self-submitted project, 225 stars, 90 forks or 90 watchers, and a repo at least 30 days old ([policy](https://docs.brew.sh/Package-Acceptance-Policy)). v1 ships from our own tap: `brew install --cask mattwelsford/aurem/aurem`. That still meets the done criterion.
9. **F9** Sleep ends the session and v1 cannot wake the Mac.

## Risks

1. **R1 Price vs free equivalent.** F1 offers the same scope for free. A paid app needs a visible reason: design, setup speed, multi-Mac. If Rimote is on the App Store and well made, conversion at US$4.99 may be low.
2. **R2 Name.** F2 and F3 are software uses of the same word. Low risk for App Store acceptance. Moderate risk for a Class 9 trademark. Because the code is MIT, a registered mark is the only protection against clones shipping under the Aurem name.
3. **R3 App Review, guideline 2.1 / 4.2.** The iPhone app does nothing without the Mac companion. Mitigated by A4 (review notes, download link, demo video). Raise again at P6.
4. **R4 App Review, local network.** iOS requires `NSLocalNetworkUsageDescription` and `NSBonjourServices`. A denied prompt makes the app useless (X12). The app must detect and explain it.
5. **R5 Licensing.** MIT allows anyone to publish a copy on the App Store, including at a lower price. This is accepted by C3. Trademark (R2) and App Store presence are the only defences.
6. **R6 Accessibility drop-off.** J5 is the largest failure point and the deciding factor for the 3-minute target.
7. **R7 Privacy label.** "Data Not Collected" holds only if Sparkle's optional system-profile reporting stays off and no crash SDK is added. Xcode Organizer crash reports come from Apple's opt-in diagnostics and do not affect the label.
8. **R8 Export compliance.** TLS through Network.framework uses OS-provided encryption, which qualifies for the standard exemption. Low risk. Answer at P6.

## G0 decision log

Matt's written answers, 2026-10-16.

| Code | Decision | Note |
|---|---|---|
| D1 | **Direction B (Dial)** approved. | Overrides the recommendation of A. Conditions for P1 are in R10. |
| D2 | Journey map approved. | |
| D3 | **Open. Name fails US clearance.** | Checks run 2026-10-16. Live US application AUREM in Class 9 for a mobile app (N1). NZ clear. aurem.app, aurem.com, getaurem.com all taken. Options O-n1 to O-n3 in [P0.5](P0.5-name-and-icon.md#options). |
| D4 | v1 scope approved with the four changes listed below. | |
| D5 | **Icon I1 (Signal)** approved. | Overrides the recommendation of I2. Must be redrawn at P1 to clear R9. |
| Q1 | Price stays US$4.99. | |
| Q3 | Matt holds touchbase.co.nz and kwa-moya.co.nz. Neither suits Aurem. A US-facing domain is needed. | Candidates to check: aurem.app, aurem.com, getaurem.com. auremapp.com is already in use (N2). |

G0 status: **not passed**. D3 is the only open item and needs Q4.

## Questions added after the decisions

1. **Q4** Name: rename now (O-n1, recommended), keep Aurem without US registration (O-n2), or consult an attorney first (O-n3)? **Answered: O-n1.**
2. **Q5** New name: Auvel (recommended) or Murmo? See [rename screening](P0.5-name-and-icon.md#rename-screening-o-n1-chosen-2026-10-16).

## Risks added after the decisions

1. **R9 Icon I1 resembles an SF Symbol.** The Signal sketch is close to `dot.radiowaves.left.and.right`. Apple's SF Symbols licence does not allow symbols, or confusingly similar designs, in app icons or logos. App Review can also reject icons that look like Apple iconography. Fix at P1: keep the dot-and-arcs idea but make the form our own, for example arcs on one side only, uneven arc weights, or arcs shaped from the "A".
2. **R10 Direction B accessibility and one-hand use.** The P0.3 comparison scored B lowest on these. These conditions apply at P1:
   1. The ring also responds to a straight vertical drag anywhere on the dial, so volume works without tracing a circle.
   2. The ring is one VoiceOver adjustable element (swipe up and down to change volume in 5% steps).
   3. Haptic detent every 5% and a stronger one at 0% and 100%.
   4. At the largest Dynamic Type sizes the volume numeral caps in size and the skip and mute buttons move into a row below the dial.

## Decisions requested at G0 (original)

1. **D1 Visual direction.** Recommend A (Control Center) with a larger play/pause tile. Alternatives: B (Dial), C (Surface).
2. **D2 Journey map.** Approve J1–J12 and the fixes for X1–X24.
3. **D3 Name.** Cannot be approved yet. Needs Q2 answered.
4. **D4 v1 scope.** Approve C6 as written, plus these concept-level changes, none of which add a feature:
   1. Sleep moves off the main screen into the Mac picker, behind a confirmation (W-D2).
   2. Play/pause is a single toggle with no play state (F5).
   3. A "volume not adjustable" state is added (F7).
   4. Homebrew ships from a project tap until the main repo accepts the cask (F8).
5. **D5 Icon.** Recommend I2 (Apex).

## Questions

1. **Q1** Given F1, do you keep US$4.99, or change the price? Recommendation: keep US$4.99. Open source plus a paid build is the stated model (C3), and the price can drop later. Raising a price is harder.
2. **Q2** For the name check, will you run the four lookups in [P0.5](P0.5-name-and-icon.md#what-is-needed-to-finish) (recommended), or allow the hosts in the environment so I can?
3. **Q3** Which domain do you already hold (C8): aurem.app, getaurem.com, or another?

## Backlog

Out-of-scope ideas are in [`/BACKLOG.md`](../../BACKLOG.md).
