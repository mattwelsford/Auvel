// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuvelKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AuvelProtocol", targets: ["AuvelProtocol"]),
    ],
    targets: [
        .target(name: "AuvelProtocol"),
        .testTarget(
            name: "AuvelProtocolTests",
            dependencies: ["AuvelProtocol"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
