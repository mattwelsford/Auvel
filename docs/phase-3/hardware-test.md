# Running Auvel on real hardware and recording G3

G3 needs a screen recording on real hardware: pausing YouTube in Safari and changing volume from the iPhone. This environment has no Mac or iPhone, so Matt runs these steps.

## 1. One-time setup (about 10 minutes)

1. Install Xcode 26 and XcodeGen: `brew install xcodegen`.
2. Clone the repo and generate both projects:
   ```sh
   git clone https://github.com/mattwelsford/auvel && cd auvel
   (cd mac && xcodegen generate)
   (cd ios && xcodegen generate)
   ```
3. Open `mac/AuvelMac.xcodeproj`. In the Auvel target, Signing & Capabilities, choose your team. Repeat in `ios/Auvel.xcodeproj`. No paid membership is needed for this: add your Apple Account in Xcode › Settings › Accounts and choose its **Personal Team**. iPhone builds signed this way expire after 7 days. Re-run from Xcode to renew.
4. Plug in the iPhone, trust the Mac, and turn on Developer Mode on the iPhone (Settings › Privacy & Security › Developer Mode).

## 2. Run

1. Run the Mac app from Xcode (⌘R). The welcome window (M03) opens.
2. Click **Open System Settings** and turn on Auvel under Accessibility. The window should change to M04 within a second.
   - Debug builds are re-signed on every build. macOS may forget the permission after a rebuild. If play/pause stops working, remove Auvel from the Accessibility list and add it again (journey X10).
3. Click **Pair iPhone**. The pairing window shows a 6-digit code (M05). If macOS asks about local network access, click **Allow**.
4. Run the iPhone app on the device. Go through I01 and I02, allow Local Network access, pick the Mac and type the code.
5. Tap **Open Remote**.

## 3. G3 recording

Record the Mac screen with QuickTime (File › New Screen Recording) and film the iPhone with a second phone, or use QuickTime's iPhone mirroring (File › New Movie Recording, choose the iPhone as camera).

| Step | Do | Expect |
|---|---|---|
| R1 | Open YouTube in Safari and play a video. | Video plays. |
| R2 | Tap the centre of the dial. | Video pauses. |
| R3 | Tap it again. | Video plays. |
| R4 | Drag around the ring from 30% to 70%. | Mac volume HUD moves. The numeral follows. |
| R5 | Drag straight up and down on the centre disc. | Volume changes. Playback does not toggle. |
| R6 | Change volume with the Mac's keys. | The iPhone dial follows within about 100 ms. |
| R7 | Tap mute, then unmute. | Mac mutes and unmutes. Arc turns grey and back. |
| R8 | Tap next and previous with a YouTube playlist. | Track changes. |

## 4. Checks to record in the G3 notes

In the same session, also fill in the Phase 4 checklists (Q13): [T6 hardware matrix](../phase-4/T6-hardware-matrix.md) and [T7 accessibility audit](../phase-4/T7-accessibility-audit.md).

| Code | Check | How | Pass |
|---|---|---|---|
| H1 | Media keys reach Safari, Music, Spotify and Chrome | Play each, tap play/pause | Each pauses |
| H2 | Volume not adjustable state (I10) | Set output to an HDMI or DisplayPort display | Banner shows, ring disabled, play/pause still works |
| H3 | Accessibility missing (I11, M02) | Turn Auvel off in Accessibility | iPhone shows banner, Mac menu shows warning row |
| H4 | Wrong code (I06, F13) | Type a wrong code | Error on iPhone, new code on Mac |
| H5 | Three wrong codes | Repeat H4 three times | Mac window shows "Pairing stopped" |
| H6 | Sleep (I15) | Mac picker › Sleep | Mac sleeps after about half a second |
| H7 | Reconnect | Lock the iPhone for 1 minute, unlock | Remote is usable within about 1 s |
| H8 | Mac quits (I12) | Quit Auvel on the Mac | Banner "Can't reach…" with Try Again |
| H9 | Unpaired | Remove the iPhone in Manage Paired iPhones | iPhone shows "Not paired with … any more" |
| H10 | Local Network denied on iPhone (I17) | Settings › Auvel › Local Network off | I17 shows, Open Settings works, list returns after allowing |
| H11 | Two iPhones | Pair a second iPhone | Both control the Mac. Both appear in M01. |
| H12 | VoiceOver | Turn on VoiceOver, swipe through the remote | Order and labels match `docs/phase-1/voiceover.md` |
| H13 | Largest text | Settings › Accessibility › Larger Text, maximum | Layout matches I19 |
| H14 | Open at Login | Log out and back in | Auvel is in the menu bar |
