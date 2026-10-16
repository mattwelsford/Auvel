# VoiceOver labels

Labels are what VoiceOver reads. Hints are read after a pause. Traits come from SwiftUI. Numbers in the first column match the focus order drawn in I21.

## iPhone remote (I08 to I13, I21)

| # | Element | Label | Value | Hint | Trait |
|---|---|---|---|---|---|
| 1 | Mac picker chip | "Mac: Matt's MacBook Pro" | — | "Double-tap to switch Mac." | Button |
| 2 | Settings | "Settings" | — | — | Button |
| 3 | Dial ring | "Volume" | "62 percent" / "Muted" / "Not adjustable on LG UltraFine" | "Swipe up or down to change by 5 percent." | Adjustable |
| 4 | Centre disc | "Play or pause" | — | — | Button. Disabled in I11 with hint "Allow media keys on your Mac first." |
| 5 | Previous | "Previous track" | — | — | Button |
| 6 | Mute | "Mute" | "On" / "Off" | — | Toggle |
| 7 | Next | "Next track" | — | — | Button |
| — | State banner (I10 to I13) | Banner title, then description | — | Action name if present, for example "Try Again" | Static text, with the action as a separate button |

Behaviour:
1. The numeral above the dial is hidden from VoiceOver because the dial's value already says it.
2. Volume changes made on the Mac post an announcement only while the dial has focus, so VoiceOver users are not interrupted.
3. Connection lost (I12): the disabled controls stay focusable and read "Dimmed". The banner is read first when the state changes (`UIAccessibility.post(notification: .screenChanged)`).

## iPhone onboarding and pairing

| Screen | Element | Label |
|---|---|---|
| I01 | Step rows | "Step 1 of 3. Install Auvel for Mac. From getauvel.com/mac or Homebrew." Each row is one element. |
| I01 | Send Mac Link… | "Send Mac link". Hint: "Opens the share sheet." |
| I05 | Code field | "Pairing code, 4 of 6 digits entered" |
| I06 | Error | Announced: "That code didn't match. 3 tries left." |
| I07 | Success | Announced: "Paired with Matt's MacBook Pro." |
| I04 | Mac row | "Matt's MacBook Pro, MacBook" / "Studio Mac mini, already paired" |
| I14 | Mac row | "Matt's MacBook Pro, connected, selected" |
| I14 | Sleep | "Sleep Matt's MacBook Pro". Hint: "Asks to confirm." |

## Mac

| Screen | Element | Label |
|---|---|---|
| M01 | Menu bar item | "Auvel, 1 iPhone connected" / "Auvel, needs attention" |
| M03 | Status line | "Waiting for permission". Changes are announced when permission is granted. |
| M05 | Code | Read as digits: "4 8 2, 9 1 6". Expiry is a separate element. |
