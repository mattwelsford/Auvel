# P1 Design system

Applies to the Auvel iPhone app, the Auvel Mac companion and the website. The apps use system components first. Brand appears in one colour, one icon and the dial.

Rendering note: the P1 renders use Inter and drawn glyphs because SF Pro and SF Symbols are not available in this build environment. The shipped apps use the system font and the SF Symbols named below.

## 1. Colour

### 1.1 System colours (both apps)

Backgrounds, labels, fills and separators use Apple semantic colours so Dark Mode, Increase Contrast and vibrancy work without custom code.

| Role | iOS | macOS |
|---|---|---|
| Screen background | `systemBackground` | window background (system) |
| Grouped background | `systemGroupedBackground` | — |
| Card / cell | `secondarySystemGroupedBackground` | `controlBackgroundColor` |
| Primary text | `label` | `labelColor` |
| Secondary text | `secondaryLabel` | `secondaryLabelColor` |
| Control fill | `tertiarySystemFill` | `quaternaryLabelColor` fill |
| Dial track | `systemFill` | — |
| Separator | `separator` | `separatorColor` |
| Error | `systemRed` | `systemRed` |
| Warning | `systemOrange` | `systemOrange` |
| Connected dot | `systemGreen` | `systemGreen` |

### 1.2 Brand colours

| Token | Light | Dark | Use |
|---|---|---|---|
| `gold` | #B7801F | #E3AC48 | Dial progress arc, knob ring, selected states, icon. Graphics only in light mode. |
| `goldText` | #94661A | #E3AC48 | Text and small glyphs in brand colour. |
| `onGold` | — | #1A1204 | Text or glyph placed on a `gold` fill in dark mode. In light mode, nothing sits on a gold fill. |
| `canvas` | #FBFAF7 | #0B0B0C | Remote screen background only. A warm tint of `systemBackground`. |
| `gold` (Increase Contrast) | #8A5F12 | #F0BE62 | Replaces `gold` when the user turns on Increase Contrast. |

Measured contrast (WCAG 2.1 formula, script output in `contrast.txt`):

| Pair | Ratio | Requirement | Result |
|---|---|---|---|
| `gold` light on white | 3.43:1 | 3:1 graphics | Pass. Fails 4.5:1 text, so never used for text. |
| `goldText` light on white | 5.03:1 | 4.5:1 text | Pass |
| `gold` dark on #1C1C1E | 8.31:1 | 4.5:1 | Pass |
| `gold` dark on `canvas` dark | 9.61:1 | 4.5:1 | Pass |
| `onGold` on `gold` dark | 9.06:1 | 4.5:1 | Pass |
| `gold` Increase Contrast light on white | 5.64:1 | 4.5:1 | Pass |

Correction to P0.3: the P0.3 note said light gold met 4.5:1. It is 3.43:1. `goldText` fixes this (F10).

### 1.3 Website

The website uses the same `gold`, `goldText` and `canvas` values as CSS custom properties, switched with `prefers-color-scheme` and `prefers-contrast: more`.

## 2. Type

All text uses Dynamic Type text styles. No fixed point sizes except where noted. All sizes below are at the default (Large) size.

### 2.1 iPhone

| Element | Style | Default size | Notes |
|---|---|---|---|
| Screen titles | `.largeTitle` bold | 34 pt | Onboarding only. |
| Navigation titles | `.headline` | 17 pt | |
| Mac name in picker chip | `.headline` | 17 pt | Truncates in the middle ("Matt's Mac…Pro"). |
| Body | `.body` | 17 pt | |
| Secondary | `.subheadline` | 15 pt | |
| Footnotes | `.footnote` | 13 pt | |
| Volume numeral | `.system(size: 64, weight: .light)` `.monospacedDigit()`, scaled relative to `.largeTitle` | 64 pt | Capped at 96 pt. Above that it stops growing and the layout reflows (§6). |
| Volume caption "VOLUME" | `.caption` semibold, 1.5 pt tracking | 12 pt | |
| Pairing code digits | `.title` semibold `.monospacedDigit()` | 28 pt | |

### 2.2 Mac

| Element | Style | Size |
|---|---|---|
| Menu items | system menu font | 13 pt |
| Window title | system | 13 pt semibold |
| Window heading | `.title3` semibold | 15 pt |
| Body | `.body` | 13 pt |
| Pairing code | `.system(size: 44, weight: .semibold)` `.monospacedDigit()` | 44 pt. Fixed, so it stays readable from about 3 m. |

### 2.3 Website

System font stack: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", system-ui, sans-serif`. No web font download, which protects the Lighthouse score. Scale: 16 / 20 / 28 / 44 / 64 px. Text column max 680 px.

## 3. Layout and spacing

1. Grid: 4 pt. Common steps 4, 8, 12, 16, 20, 24, 32, 48.
2. iPhone side margins: 20 pt. Sheet content insets: 20 pt.
3. Mac window padding: 20 pt. Menu: system.
4. Corners: continuous (`RoundedRectangle(cornerRadius:style: .continuous)`). Buttons are capsules. Cards 16 pt. Mac window controls 6 pt.
5. Minimum hit target: 44 × 44 pt on iPhone, even when the visible shape is smaller.

### 3.1 Remote (Direction B, Dial) dimensions at default size

| Part | Size |
|---|---|
| Dial outer diameter | 330 pt (scales down to fit on smaller phones, minimum 280 pt) |
| Ring stroke | 22 pt |
| Knob | 34 pt circle, white with 1 pt `separator` stroke |
| Centre disc (play/pause) | 208 pt |
| Previous / Mute / Next buttons | 72 pt circles, 28 pt apart |
| Mac picker chip | 44 pt high |

## 4. SF Symbols

Rendering mode: hierarchical unless noted. Weight follows the adjacent text.

| Control or state | Symbol |
|---|---|
| Play/pause | `playpause.fill` |
| Previous / next | `backward.fill` / `forward.fill` |
| Volume 0 / 1–33 / 34–66 / 67–100 | `speaker.fill` / `speaker.wave.1.fill` / `speaker.wave.2.fill` / `speaker.wave.3.fill` |
| Muted | `speaker.slash.fill` |
| Volume not adjustable | `speaker.badge.exclamationmark.fill` |
| Mac (by model) | `laptopcomputer`, `desktopcomputer`, `macmini`, `macstudio`, `display` from the Mac's model identifier, fallback `laptopcomputer` |
| Picker | `chevron.down` |
| Settings | `gearshape` |
| Sleep | `moon.fill` |
| Connection lost | `wifi.exclamationmark` |
| Accessibility needed | `hand.raised.fill` |
| Local network denied | `network.slash` (confirm in the SF Symbols app at P3, fallback `network`) |
| Update needed | `arrow.down.circle` |
| Success | `checkmark.circle.fill` |
| Error | `exclamationmark.triangle.fill` |
| Retry | `arrow.clockwise` |

The app icon and menu bar icon are custom drawings, not SF Symbols. The SF Symbols licence does not allow symbols in app icons or logos (R9).

## 5. Motion

1. Only state changes animate. Nothing loops except the system `ProgressView` while searching or reconnecting.
2. Dial knob and arc follow the finger with no animation. When the Mac reports a new volume from elsewhere, the arc animates with `.spring(response: 0.3, dampingFraction: 0.85)`.
3. Button press: scale to 0.96 over 0.1 s, back on release.
4. Banners and state changes: 0.2 s crossfade.
5. Sheets: system default.
6. Reduce Motion on: springs and scaling are replaced with crossfades. Durations stay the same.

## 6. Dynamic Type and accessibility behaviour

1. Sizes up to xxxLarge: layout unchanged, text grows.
2. Accessibility sizes (AX1–AX5): the dial shrinks to 260 pt. The volume numeral caps at 96 pt. Previous, mute and next move into a full-width row of 72 pt buttons below the dial with text labels under each. The Mac picker chip becomes a full-width row.
3. VoiceOver: the dial is one adjustable element (R10). Swipe up or down changes volume by 5%. The centre disc is a separate button. Labels are listed in `voiceover.md`.
4. The ring also accepts a straight vertical drag anywhere on the dial. Up raises volume. One full dial height equals 100%.
5. Bold Text and Button Shapes are respected through system components.

## 7. Haptics (iPhone)

| Event | Feedback |
|---|---|
| Play/pause, previous, next sent | `UIImpactFeedbackGenerator(style: .rigid)` |
| Volume crosses each 5% step while dragging | `UISelectionFeedbackGenerator` |
| Volume reaches 0% or 100% | `.impact(.medium)` |
| Mute or unmute | `.impact(.light)` |
| Pairing succeeded | `.notification(.success)` |
| Wrong pairing code, command failed | `.notification(.error)` |
| Connection lost | none. A silent visual change avoids buzzing every time the phone wakes. |

The Haptics setting turns all of these off. The Mac app uses no haptics.

## 8. Voice and copy

1. Name the Mac by its user-set name, never "your computer".
2. Say what happened and what to do, in that order. "Can't reach Matt's MacBook Pro. It may be asleep or on another Wi-Fi network."
3. No exclamation marks, no "Oops".
4. Buttons are verbs: "Try Again", "Open Settings", "Pair".
