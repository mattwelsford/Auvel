# Auvel

Control your Mac's media and volume from your iPhone, over your local network. MIT licensed.

Status: Phase 2 skeleton. The apps build but do nothing yet.

## Layout

| Folder | Contents |
|---|---|
| `shared/` | `AuvelKit` Swift package. The `AuvelProtocol` library holds the wire protocol used by both apps. |
| `mac/` | Auvel for Mac, a menu bar app. Distributed outside the Mac App Store. |
| `ios/` | Auvel for iPhone. |
| `site/` | Static website. |
| `docs/` | Phase documents, protocol spec, threat model and decision records. |

## Build

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
# Shared package
swift test --package-path shared

# Mac app
cd mac && xcodegen generate && open AuvelMac.xcodeproj

# iPhone app
cd ios && xcodegen generate && open Auvel.xcodeproj
```

The Xcode projects are generated from `project.yml` and are not committed. See [ADR-001](docs/phase-2/adr/ADR-001-monorepo-xcodegen.md).
