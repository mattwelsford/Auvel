# Backlog

Ideas outside the current phase's scope. Logged, not built.

| Code | Idea | Source | Note |
|---|---|---|---|
| B1 | iPhone hardware volume buttons control Mac volume. | P0.3 | Large win for the across-the-room case. Needs a workaround that observes `AVAudioSession.outputVolume` and resets it, which App Review may treat as hijacking the buttons. Investigate before proposing. |
| B2 | Wake the Mac with Wake-on-LAN. | P0.4 X23 | Needs the Mac's MAC address, "Wake for network access" on, and the phone on the same layer-2 network. Excluded by C6. |
| B3 | Manual Mac address entry when Bonjour fails. | P0.4 X13 | Helps guest networks and mesh routers that block multicast. |
| B4 | Control Center control and Lock Screen widget for play/pause. | P0.3 | iOS 18 Controls API. Fast access without opening the app. |
| B5 | Shortcuts / App Intents: "Pause my Mac". | P0.1 | Also enables Siri and the Action button. |
| B6 | Apple Watch app. | P0.1 (Rimote user request) | Excluded by C6. |
| B7 | Now Playing metadata. | F5 | Excluded by C5 and C6. Revisit only if Apple provides a public API. |
| B8 | Mac advertises laptop or desktop in its TXT record so the iPhone shows the right icon. | P3 F17 | Apple silicon model identifiers do not say. The Mac can check for an internal battery. |
