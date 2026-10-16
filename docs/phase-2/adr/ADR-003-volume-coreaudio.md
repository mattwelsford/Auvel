# ADR-003 Volume and mute through CoreAudio

Status: proposed at G2.

## Decision

1. Read the default output device with `kAudioHardwarePropertyDefaultOutputDevice`.
2. Get and set volume with `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on the output scope. Get and set mute with `kAudioDevicePropertyMute`.
3. Check `AudioObjectIsPropertySettable` before showing volume as adjustable. Report the result as `volume_settable` (protocol §5.2).
4. Listen for changes to the default device, volume and mute, and push `state` to clients.

## Consequences

1. Outputs without software volume, common on HDMI and DisplayPort displays, report `volume_settable: false`. The iPhone shows I10 (F7).
2. Needs no special permission, so volume works before Accessibility is granted (W-D5).
