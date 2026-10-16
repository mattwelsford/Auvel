# ADR-005 Pairing with a 6-digit code using commitment rounds

Status: proposed at G2.

## Context

The approved design (I05, M05) has the user type a 6-digit code shown on the Mac into the iPhone. Six digits is about 20 bits. Any scheme where an attacker can see a value derived from the code and then test guesses offline is broken in milliseconds.

## Options

| Code | Option | Verdict |
|---|---|---|
| O-p1 | Use the code as the TLS PSK, as in Apple's Network.framework sample | Rejected. An active attacker on the network captures one handshake and brute-forces the code offline. |
| O-p2 | A PAKE such as SPAKE2+ (used by Matter) | Strong and standard, but needs elliptic-curve point arithmetic that CryptoKit does not expose. Requires a third-party crypto dependency. |
| O-p3 | Bluetooth LE Secure Connections Passkey Entry: ECDH plus 20 commit-reveal rounds, one per code bit | Chosen. Published, analysed method. Needs only CryptoKit (P-256, HMAC, HKDF). Attacker success at most 2⁻²⁰ per attempt. |

## Decision

O-p3, as specified in protocol §6. The resulting 256-bit key becomes the TLS PSK (ADR-004).

## Consequences

1. A failed attempt leaks code bits, so the Mac shows a new code after every failure. **This changes approved screen I06.** "3 tries left" becomes "That code didn't match. Enter the new code shown on your Mac." The Mac window closes after 3 failed attempts (F13).
2. 40 extra small messages per pairing. Under 100 ms on a local network.
3. New security-critical code (R14). An outside review before launch is recommended.
