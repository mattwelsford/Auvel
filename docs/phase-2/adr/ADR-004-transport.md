# ADR-004 Network.framework, Bonjour and TLS with a pre-shared key

Status: proposed at G2.

## Decision

1. `NWListener` on the Mac and `NWBrowser` / `NWConnection` on the iPhone. No third-party networking code.
2. Two Bonjour services: control (`_auvel._tcp`, always) and pairing (`_auvel-pair._tcp`, only while pairing). Protocol §2.
3. Control connections use TLS with the 256-bit pairing key as a PSK and the iPhone's device ID as PSK identity (protocol §7).
4. Length-prefixed JSON frames (protocol §3) rather than `NWProtocolFramer` or a binary format. JSON is readable in logs and fixtures, and v1 message volume is tiny.

## Alternatives considered

1. Self-signed certificates with pinning. Needs X.509 generation and Keychain identity handling on iOS. More code for the same result as PSK.
2. Binary encoding (Protocol Buffers). Adds a dependency and makes fixtures unreadable.

## Consequences

1. TLS 1.2 PSK has no forward secrecy (R13). P3 checks whether TLS 1.3 PSK with ECDHE is available in Network.framework.
2. Per-identity PSK selection on the Mac must be confirmed on hardware (protocol §7.3).
