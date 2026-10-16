import AuvelProtocol
import SwiftUI

/// P2 skeleton: one placeholder screen. P3 builds the I01–I21 designs.
@main
struct AuvelApp: App {
    var body: some Scene {
        WindowGroup {
            ContentUnavailableView(
                "Auvel",
                systemImage: "hammer",
                description: Text("Skeleton build · protocol v\(ProtocolVersion.current)")
            )
        }
    }
}
