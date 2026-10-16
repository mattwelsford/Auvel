// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuvelKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AuvelProtocol", targets: ["AuvelProtocol"]),
        .library(name: "AuvelTransport", targets: ["AuvelTransport"]),
        .library(name: "AuvelSession", targets: ["AuvelSession"]),
        .library(name: "AuvelTestSupport", targets: ["AuvelTestSupport"]),
    ],
    targets: [
        // Wire format, pairing and versioning. Pure Swift plus CryptoKit.
        .target(name: "AuvelProtocol"),
        // Network.framework connections: TLS-PSK parameters and framed message streams.
        .target(name: "AuvelTransport", dependencies: ["AuvelProtocol"]),
        // Per-connection protocol logic for both apps, free of networking so the same fixtures test both sides (T2).
        .target(name: "AuvelSession", dependencies: ["AuvelProtocol"]),
        // Mock Mac server for iPhone tests without a Mac (T5). Test-only: never linked into the apps.
        .target(name: "AuvelTestSupport", dependencies: ["AuvelProtocol", "AuvelTransport", "AuvelSession"]),
        .testTarget(
            name: "AuvelProtocolTests",
            dependencies: ["AuvelProtocol"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "AuvelTransportTests", dependencies: ["AuvelTransport"]),
        // Reads the fixtures in AuvelProtocolTests/Fixtures from the source tree, so there is one copy.
        .testTarget(name: "AuvelSessionTests", dependencies: ["AuvelSession"]),
        .testTarget(name: "AuvelTestSupportTests", dependencies: ["AuvelTestSupport"]),
    ]
)
