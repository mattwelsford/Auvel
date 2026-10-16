# ADR-006 Mac distribution: Developer ID, notarisation, Sparkle, project Homebrew tap

Status: proposed at G2.

## Decision

1. The Mac app is signed with Matt's Developer ID Application certificate, uses the hardened runtime and is notarised with `notarytool`. Releases are DMGs on GitHub Releases.
2. Auto-update with Sparkle 2 (Swift Package). Updates are signed with an EdDSA key. The appcast is served from the website over HTTPS.
3. Homebrew: a project tap, `mattwelsford/homebrew-auvel`, installed with `brew install --cask mattwelsford/auvel/auvel`. Submit to `homebrew/cask` once it meets the notability rules (F8).
4. Signing material is stored only as GitHub encrypted secrets for the release workflow (R12). CI on pull requests never has access to it.

## Consequences

1. Matt creates the certificates and Sparkle keys and adds them as secrets (C8). I will list the exact secrets at P6.
2. Sparkle's optional system profiling stays off, to keep "Data Not Collected" true (R7).
