# Auvel protocol, version 1

Status: draft for G2. Code: `shared/Sources/AuvelProtocol`. Canonical examples: `shared/Tests/AuvelProtocolTests/Fixtures`. Items marked **P3-verify** depend on Network.framework behaviour that must be confirmed on hardware in Phase 3.

## 1. Roles

| Role | Runs on | Does |
|---|---|---|
| Mac | Auvel for Mac | Advertises, accepts connections, executes commands. |
| Client | Auvel for iPhone | Discovers Macs, pairs, sends commands. |

A client may be paired with several Macs. A Mac may be paired with several clients and accepts up to 4 control connections at once.

## 2. Discovery

| Service | Type | Advertised | TXT keys |
|---|---|---|---|
| Control | `_auvel._tcp` | Always, while Auvel for Mac runs | `v` highest protocol version, `id` Mac install UUID, `model` hardware model identifier |
| Pairing | `_auvel-pair._tcp` | Only while the Mac's pairing window (M05) is open | `id` |

The Bonjour service name is the Mac's user-visible computer name. Clients identify a Mac by `id`, never by name or IP address, so renames and DHCP changes do not break pairing. Both types are listed in each app's `NSBonjourServices`.

## 3. Framing

Every message on both services is one frame: a 4-byte big-endian payload length, then that many bytes of UTF-8 JSON. Maximum payload 16 KiB. A receiver closes the connection on a larger length prefix without reading the payload.

Every frame is an envelope:

```json
{"v":1,"id":7,"type":"set_volume","body":{"level":0.62}}
```

| Field | Meaning |
|---|---|
| `v` | Envelope version. Always 1 in this spec. Any other value closes the connection. |
| `id` | Sender's message number, `UInt32`, starting at 1 and increasing per connection. |
| `type` | Message type, snake_case. Unknown types get `failure` `bad_request` and the connection stays open. |
| `reply_to` | On `ok` and `failure` only: the `id` being answered. |
| `body` | Type-specific object. Omitted when a type has no fields. |

Senders encode with sorted keys. Receivers must not depend on key order.

## 4. Version negotiation

1. The client's `hello` lists every message-set version it supports in `versions`.
2. The Mac picks the highest version both support and returns it in `hello_ack.version`.
3. If there is no overlap, the Mac sends `failure` `unsupported_version` with `minimum_version`, then closes. The client shows I13 ("Update Auvel on your Mac") if its own versions are higher, or asks the user to update the iPhone app if lower.
4. New message types or fields within a version must be optional for the receiver. Anything else needs a new version number.

## 5. Control messages (service `_auvel._tcp`, inside TLS)

### 5.1 Client to Mac

| `type` | `body` | Mac's reply |
|---|---|---|
| `hello` | `versions` [Int], `device_id` UUID, `device_name` String, `app_version` String | `hello_ack`, then `state` |
| `command` | `command`: `play_pause`, `next` or `previous` | `ok`, or `failure` `media_keys_not_allowed` |
| `set_volume` | `level` Double, 0...1 | `ok`, or `failure` `volume_not_settable`. Out-of-range values are rejected as `bad_request`. |
| `set_muted` | `muted` Bool | `ok`, or `failure` `volume_not_settable` |
| `sleep` | — | `ok`, then the Mac sleeps after 500 ms |
| `get_state` | — | `state` |
| `ping` | — | `pong` |

The first message on a connection must be `hello`. Anything else first gets `bad_request` and the connection is closed.

### 5.2 Mac to client

| `type` | `body` | Sent |
|---|---|---|
| `hello_ack` | `version`, `mac_name`, `model`, `app_version` | Once, after `hello` |
| `state` | `volume` 0...1, `muted`, `volume_settable`, `output_name`, `media_keys_allowed` | After `hello_ack`, after `get_state`, and whenever any field changes on the Mac |
| `ok` | — (`reply_to` set) | Command accepted |
| `failure` | `code`, optional `minimum_version` (`reply_to` set) | Command refused |
| `pong` | — | Reply to `ping` |

Error codes: `unsupported_version`, `media_keys_not_allowed`, `volume_not_settable`, `bad_request`, `rate_limited`, `internal`.

### 5.3 Timing and limits

1. The client sends `ping` every 15 s while the remote is on screen. The Mac closes a connection after 45 s without a frame.
2. While the user drags the dial the client sends `set_volume` at most every 50 ms. The Mac applies the latest value.
3. More than 50 frames in any 1 s window gets `failure` `rate_limited` and the connection is closed.
4. `state` pushes are coalesced to at most one per 100 ms.

## 6. Pairing (service `_auvel-pair._tcp`)

Pairing establishes a 256-bit key shared by one iPhone and one Mac. The user types a 6-digit code shown on the Mac into the iPhone. The method follows the Passkey Entry procedure of Bluetooth LE Secure Connections (Bluetooth Core Specification, Vol 3, Part H, §2.3.5.6.3), using only CryptoKit primitives: P-256 key agreement, HMAC-SHA256 and HKDF-SHA256. ADR-005 explains the choice.

Pairing frames use the same framing and envelope as §3, without TLS. They carry public keys, commitments and nonces, never the code or the derived key.

### 6.1 Steps

Notation: `PKc`, `PKm` are the client's and Mac's ephemeral P-256 public keys (X9.63 encoding, base64 in JSON). `r` is the code, 0 to 999,999, written as 20 bits `r1…r20`, most significant first. `ri'` is the byte `0x80 | ri`. `||` is concatenation. `HMAC(k, m)` is HMAC-SHA256.

| # | Direction | `type` | Body |
|---|---|---|---|
| 1 | Client → Mac | `pair_hello` | `versions`, `device_id`, `device_name`, `public_key` (`PKc`) |
| 2 | Mac → Client | `pair_hello_ack` | `mac_id`, `mac_name`, `public_key` (`PKm`) |
| 3 | Both | — | Compute `DHKey = ECDH(own private key, peer public key)` |
| 4 | Repeat for i = 1…20 | | |
| 4a | Client → Mac | `pair_commit` | `round` i, `commitment` `Cci = HMAC(Nci, PKc ‖ PKm ‖ ri')` with fresh 128-bit `Nci` |
| 4b | Mac → Client | `pair_commit` | `round` i, `commitment` `Cmi = HMAC(Nmi, PKm ‖ PKc ‖ ri')` with fresh 128-bit `Nmi` |
| 4c | Client → Mac | `pair_reveal` | `round` i, `nonce` `Nci`. Mac recomputes `Cci` with its own `ri`. Mismatch: fail. |
| 4d | Mac → Client | `pair_reveal` | `round` i, `nonce` `Nmi`. Client recomputes `Cmi` with the typed `ri`. Mismatch: fail. |
| 5 | Both | — | `T = SHA256` over these fields in order, each prefixed with its 2-byte big-endian length: `device_id` (16 bytes), `device_name` (UTF-8), `PKc`, `mac_id`, `mac_name`, `PKm`, then for each round `Cci`, `Cmi`, `Nci`, `Nmi`. `K = HKDF-SHA256(ikm: DHKey, salt: Nc20 ‖ Nm20, info: "auvel pairing v1" ‖ PKc ‖ PKm ‖ T, length: 32)` |
| 6 | Client → Mac | `pair_confirm` | `mac` = `HMAC(K, "client" ‖ T)`. Mac verifies. |
| 7 | Mac → Client | `pair_confirm` | `mac` = `HMAC(K, "mac" ‖ T)`. Client verifies. |
| 8 | Both | — | Store the peer's ID, name and `K` in the Keychain. Discard ephemeral keys. |

### 6.2 Rules

1. The Mac accepts one pairing connection at a time.
2. Any failure ends the session. The Mac discards the code and shows a new one. A code is never reused after a failed session, because each failed round reveals one bit.
3. After 3 failed sessions in one window the Mac closes the pairing window. The user must reopen it from the menu.
4. The code expires after 5 minutes. The pairing service is withdrawn when the window closes.
5. Keychain storage: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, not synchronised to iCloud.

### 6.3 Security property

An attacker who does not know the code, including one in the middle of the connection, succeeds with probability at most 2⁻²⁰ per session. Each round commits to one bit before either side reveals its nonce, so the attacker cannot test guesses offline. Fresh codes per session (rule 2) stop a failed attacker from carrying learned bits forward.

## 7. Control connection security

1. Transport: TCP with TLS through Network.framework, using the pairing key `K` as a pre-shared key. PSK identity: the client's `device_id` (16 bytes).
2. Cipher suite: `TLS_PSK_WITH_AES_128_GCM_SHA256` over TLS 1.2. This is the configuration in Apple's Network.framework peer-to-peer sample. **P3-verify:** whether Network.framework supports TLS 1.3 external PSK with ECDHE on iOS 18 and macOS 15. If it does, use it for forward secrecy.
3. The Mac registers one PSK per paired client, keyed by identity. **P3-verify:** that Network.framework selects the PSK by the client's identity. Fallback: a per-connection selection block.
4. A failed TLS handshake from a known `device_id` means the Mac removed that client. The client shows "Not paired with this Mac any more" and offers to pair again.

## 8. Fixtures

Every message in §5 has a canonical JSON file in `shared/Tests/AuvelProtocolTests/Fixtures`. Files named `invalid_*` must be rejected. The shared tests check decode and byte-exact encode. In P4 the same files drive the T2 contract tests against both apps.
