# T7 VoiceOver and Accessibility Inspector audit

Fill in on a real iPhone (VoiceOver) and with Xcode's Accessibility Inspector (Xcode › Open Developer Tool › Accessibility Inspector) on the iPhone and the Mac. Expected labels are in [voiceover.md](../phase-1/voiceover.md). G4 needs every row filled.

Tester: ______  Date: ______  Auvel build: ______

## iPhone, VoiceOver on

| Code | Check | Result | Notes |
|---|---|---|---|
| V1 | Remote focus order is 1 Mac chip, 2 Settings, 3 Volume, 4 Play or pause, 5 Previous, 6 Mute, 7 Next | | |
| V2 | Volume reads "Volume, 62 percent" (or the current value) and swipe up/down changes it by the Volume Step setting | | |
| V3 | Volume reads "Muted" when muted and "Not adjustable" on I10 | | |
| V4 | Play or pause is announced as a button. Double-tap toggles playback | | |
| V5 | Mute is announced as a toggle with "On" or "Off" | | |
| V6 | The volume numeral is not read separately | | |
| V7 | State banners (I10 to I13) are read, and their action buttons are reachable | | |
| V8 | Onboarding steps read "Step 1 of 3…" as one element each | | |
| V9 | Pairing code field reads "Pairing code, n of 6 digits entered" | | |
| V10 | "Paired with …" is announced on I07 | | |
| V11 | Mac picker rows read the name and status, and the selected Mac is announced as selected | | |
| V12 | Sleep asks for confirmation and the dialog is read | | |

## iPhone, Accessibility Inspector audit

| Code | Check | Result | Notes |
|---|---|---|---|
| A1 | Run Audit on I01, I08, I14 and I16: no contrast warnings | | |
| A2 | No hit regions under 44 × 44 pt | | |
| A3 | No elements without labels | | |
| A4 | Dynamic Type at AX5: nothing clipped on I08 (compare with I19) and I01 (compare with I20) | | |
| A5 | Bold Text, Button Shapes, Reduce Motion, Increase Contrast: remote still usable, gold switches to the high-contrast value | | |

## Mac, VoiceOver on (⌘F5)

| Code | Check | Result | Notes |
|---|---|---|---|
| M1 | Menu bar item reads "Auvel", "Auvel, 1 iPhone connected" or "Auvel, needs attention" | | |
| M2 | Every menu item is reachable and named | | |
| M3 | Welcome window: steps, status line and both buttons are read. The change to "Media key control is on" is announced | | |
| M4 | Pairing code is read digit by digit | | |
| M5 | Paired iPhones list: Remove buttons read "Remove <name>" | | |
