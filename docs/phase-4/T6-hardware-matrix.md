# T6 Manual hardware matrix

Fill in on real devices. Mark each cell **Pass**, **Fail** (with a note) or **N/A**. G4 needs every cell filled.

Devices: two macOS versions (15 and 26) and two iOS versions (18 and 26), per ADR-007.

Tester: ______  Date: ______  Auvel build: ______

## Setup recorded

| | Mac A | Mac B |
|---|---|---|
| Model | | |
| macOS version | 15.__ | 26.__ |
| Audio output used | | |

| | iPhone A | iPhone B |
|---|---|---|
| Model | | |
| iOS version | 18.__ | 26.__ |

## Media keys (play/pause, next, previous)

For each app, start playback on the Mac, then use the iPhone remote.

| App | Mac A × iPhone A | Mac A × iPhone B | Mac B × iPhone A | Mac B × iPhone B | Notes |
|---|---|---|---|---|---|
| Safari, YouTube: play/pause | | | | | |
| Safari, YouTube playlist: next / previous | | | | | |
| Music: play/pause | | | | | |
| Music: next / previous | | | | | |
| Spotify: play/pause | | | | | |
| Spotify: next / previous | | | | | |
| Chrome, YouTube: play/pause | | | | | |
| Chrome, YouTube playlist: next / previous | | | | | |

## Volume

| Check | Mac A × iPhone A | Mac B × iPhone B | Notes |
|---|---|---|---|
| Drag around the ring changes Mac volume, HUD shows | | | |
| Vertical drag on the centre disc changes volume and does not toggle playback | | | |
| Mac volume keys update the iPhone dial | | | |
| Mute and unmute | | | |
| HDMI or DisplayPort output: I10 notice, ring disabled | | | |
| Bluetooth headphones as output | | | |

## Connection

| Check | Mac A × iPhone A | Mac B × iPhone B | Notes |
|---|---|---|---|
| First pairing under 3 minutes from app install (time it) | | | Time: |
| Wrong code shows I06 and the Mac shows a new code | | | |
| Reconnect after locking the iPhone for 1 minute, usable within about 1 s | | | |
| Mac app quit: I12 banner, recovers when relaunched | | | |
| Sleep from the Mac picker | | | |
| Two paired Macs: switch in the picker | | | |
| Mac removes the iPhone: "Not paired" banner | | | |
| Open at Login after logout and login | | | |
