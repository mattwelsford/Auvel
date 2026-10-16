# Threat model: local-network link

Scope: the link between Auvel for iPhone and Auvel for Mac, and what each app exposes on the local network. Method: assets, attackers, entry points, then STRIDE per entry point. Protocol details are in [protocol.md](protocol.md).

## 1. Assets

| Code | Asset | Why it matters |
|---|---|---|
| AS1 | Control of the Mac's media keys, volume and sleep | Misuse is a nuisance: pausing, blasting volume, sleeping the Mac mid-work. |
| AS2 | Pairing keys `K` on both devices | Whoever holds one can control that Mac. |
| AS3 | The Mac app's Accessibility grant | It lets Auvel post keyboard events. A compromised Auvel could type anything. |
| AS4 | Device names and Mac model | Low sensitivity, but they identify people ("Matt's iPhone"). |
| AS5 | Update channel for the Mac app | A malicious update would inherit AS3. |

## 2. Attackers

| Code | Attacker | Capability |
|---|---|---|
| AT1 | Someone on the same Wi-Fi network (housemate, café, guest) | Sees Bonjour adverts, connects to any port, can be active man-in-the-middle via ARP spoofing. |
| AT2 | Malicious app on the same Mac | Runs as the same user. Can read the user's files but not other apps' Keychain items. |
| AT3 | Malicious app on the iPhone | Sandboxed. Cannot read Auvel's Keychain. |
| AT4 | Network attacker between the Mac and GitHub | Tries to tamper with updates. |
| AT5 | Someone who borrows the unlocked iPhone | Physical access to the app. |

Out of scope: an attacker with root on the Mac, a jailbroken iPhone, or the user's Apple ID.

## 3. Entry points

| Code | Entry point | Exposure |
|---|---|---|
| E1 | Control service `_auvel._tcp` | Always listening while Auvel for Mac runs |
| E2 | Pairing service `_auvel-pair._tcp` | Only while the pairing window is open (at most 5 minutes) |
| E3 | Bonjour TXT records | Always |
| E4 | Keychain items | At rest on both devices |
| E5 | Sparkle update feed and download | When checking for updates |

## 4. STRIDE

| Code | Threat | Entry | Mitigation | Residual |
|---|---|---|---|---|
| T1 | **Spoofing.** AT1 connects to E1 and sends commands. | E1 | TLS with a per-client PSK. No PSK, no handshake. Commands are accepted only after `hello` on an authenticated connection. | None known. |
| T2 | **Spoofing.** AT1 pairs during the window by guessing the code. | E2 | Commitment rounds give at most 2⁻²⁰ success per session. A new code after every failure. Window closes after 3 failures. One session at a time. | 3 × 2⁻²⁰ per window, about 1 in 350,000. Accepted. |
| T3 | **Spoofing / MITM.** AT1 relays between iPhone and Mac during pairing. | E2 | Same commitment scheme. Both public keys are inside every commitment and in the HKDF info, so a relayed session derives different keys and fails confirmation. | Same as T2. |
| T4 | **Spoofing.** AT1 advertises a fake Mac with the same name. | E3 | Clients trust a Mac by `id` plus a successful PSK handshake, never by name. An unpaired fake shows up only in the "Add a Mac" list, and pairing with it gives it nothing. | A user could pair with a fake by mistake. It gains only the ability to receive commands. Accepted. |
| T5 | **Tampering.** AT1 modifies frames in transit. | E1 | AES-GCM inside TLS. | None known. |
| T6 | **Repudiation.** No record of which iPhone did what. | E1 | Not required for a media remote. The Mac shows connected iPhones in M01. | Accepted. |
| T7 | **Information disclosure.** AT1 reads commands. | E1 | TLS. | No forward secrecy with TLS 1.2 PSK: a stolen `K` decrypts recorded traffic. Traffic is volume and play commands only. P3 checks for TLS 1.3 PSK with ECDHE (protocol §7.2). |
| T8 | **Information disclosure.** Bonjour reveals the Mac's name and model. | E3 | Name is the existing computer name macOS already advertises. `model` is used for an icon only. | Accepted. |
| T9 | **Information disclosure.** AT2 or AT3 reads `K`. | E4 | Keychain, `ThisDeviceOnly`, no iCloud sync. Other apps cannot read Auvel's items. | AT2 with the user's password could use Keychain Access. Out of scope (equivalent to user compromise). |
| T10 | **Denial of service.** AT1 floods E1 or E2. | E1, E2 | 16 KiB frame cap checked before reading the payload. 50 frames/s limit. 4 connection cap. 45 s idle timeout. `hello` required first. | AT1 can occupy connection slots. Paired clients get priority by evicting unauthenticated connections first (P3). |
| T11 | **Denial of service.** AT1 blocks pairing by keeping E2 busy. | E2 | Window lasts 5 minutes and the user can reopen it. | Accepted. |
| T12 | **Elevation of privilege.** A crafted frame makes the Mac do more than media, volume or sleep. | E1 | Fixed command set. No shell, no scripts, no file access, no free-form key events. Strict decoding rejects unknown types and out-of-range values (fixtures `invalid_*`). | None known. |
| T13 | **Elevation of privilege.** Malicious update inherits Accessibility (AS3). | E5 | Sparkle 2 with EdDSA signatures, HTTPS feed, Developer ID signing and notarisation. The signing key is held by Matt, not in CI logs. | Compromise of Matt's signing key. See R12. |
| T14 | **Elevation of privilege.** AT2 injects code into Auvel for Mac to use its Accessibility grant. | — | Hardened runtime, no `disable-library-validation` entitlement. | Out of scope beyond hardened runtime. |
| T15 | **Physical.** AT5 uses the unlocked iPhone. | — | Same as any unlocked phone. Effect limited to AS1. | Accepted. |

## 5. Rules the code must follow

1. The Mac never executes anything that is not in protocol §5.1.
2. Decoding is strict: unknown `type`, out-of-range values and oversized frames are rejected before any action.
3. The pairing service listens only while the pairing window is open.
4. Pairing keys live only in the Keychain, never in `UserDefaults`, logs or crash reports.
5. Logs never contain codes, nonces, keys or command payloads beyond the message type.
6. No analytics or network calls other than the local link and Sparkle's update check (C4, privacy label).

## 6. Risks for the register

1. **R12 Signing keys.** The Developer ID certificate and Sparkle EdDSA key together allow shipping code with Accessibility access to every user. Keep them out of the repository. Store them as GitHub encrypted secrets used only by the release workflow, with branch protection on the release branch. Matt holds the originals (C8).
2. **R13 No forward secrecy** on the TLS 1.2 PSK fallback (T7). Low impact. Resolved if P3 confirms TLS 1.3 PSK with ECDHE.
3. **R14 Home-grown pairing protocol.** The pairing method follows a published standard, but this implementation is new code. Mitigations: the P4 unit tests cover each round's failure path, fixtures include tampered commitments, and the code is short enough to review in one sitting. An outside review before launch is recommended.
