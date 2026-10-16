import AuvelProtocol
import AuvelTestSupport
import XCTest

/// T3: pairing, control and reconnect, against the mock Mac (T5) running in the test process.
/// The mock advertises over Bonjour like the real Mac, so the app finds it through the normal discovery path.
@MainActor
final class RemoteFlowUITests: XCTestCase {
    private var server: MockMacServer!
    private var app: XCUIApplication!
    private var macName = ""

    override func setUp() async throws {
        continueAfterFailure = false
        // A unique name so a real Mac on the same network cannot be picked by mistake.
        macName = "Mock Mac \(Int.random(in: 1000...9999))"
        server = MockMacServer(.init(
            identity: .init(name: macName, model: "Mac15,3", appVersion: "1.0"),
            advertise: true
        ))
        try await server.start()
        app = XCUIApplication()
        app.launchArguments = ["-AuvelResetForUITests"]
        app.launch()
    }

    override func tearDown() async throws {
        app?.terminate()
        server?.stop()
    }

    /// Onboarding, discovery, pairing with the code, then the remote (I01 → I02 → I04 → I05 → I07 → I08).
    private func pairThroughUI() {
        app.buttons["It's Installed"].tap()
        let next = app.buttons["Continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        // The first test after the simulator boots can take a while for Bonjour to resolve.
        let row = app.buttons[macName]
        XCTAssertTrue(row.waitForExistence(timeout: 30), "Mock Mac not discovered over Bonjour")
        row.tap()

        app.typeText(server.configuration.passkey.description.replacingOccurrences(of: " ", with: ""))
        let open = app.buttons["Open Remote"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Pairing did not complete")
        open.tap()
    }

    private func waitForServer(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    func testPairing() {
        pairThroughUI()
        XCTAssertTrue(app.buttons["Mac: \(macName)"].waitForExistence(timeout: 5))
        XCTAssertEqual(server.pairedDeviceIDs.count, 1)
    }

    func testControl() {
        pairThroughUI()
        let play = app.buttons["Play or pause"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForServer { self.app.otherElements["Volume"].exists || self.app.adjustableElement.exists })
        // The remote appears before the session connects. Controls stay disabled until then.
        XCTAssertTrue(waitForServer({ play.isEnabled }, timeout: 10), "Remote did not connect")

        play.tap()
        XCTAssertTrue(waitForServer { self.server.receivedCommands.contains(.command(.playPause)) }, "Play/pause not received")

        app.buttons["Next track"].tap()
        XCTAssertTrue(waitForServer { self.server.receivedCommands.contains(.command(.next)) }, "Next not received")

        // Mute carries the toggle trait (T7 V5), so XCUITest exposes it as a switch.
        app.switches["Mute"].tap()
        XCTAssertTrue(waitForServer { self.server.state.muted }, "Mute not received")

        // The dial's vertical drag changes volume (XCUIElement has no increment action on iOS).
        app.adjustableElement.swipeUp()
        XCTAssertTrue(waitForServer { self.server.receivedCommands.contains { if case .setVolume = $0 { true } else { false } } },
                      "Volume change not received")
    }

    func testReconnect() async throws {
        pairThroughUI()
        let play = app.buttons["Play or pause"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))

        // The Mac's control service goes away and comes back on a new port, as after a Mac app restart.
        try await server.restartControl()

        // The app may not have noticed the drop yet, so a tap can land on the dead connection.
        // Keep tapping until the command arrives on the new port.
        let reconnected = waitForServer({
            if self.server.receivedCommands.contains(.command(.playPause)) { return true }
            if play.isEnabled { play.tap() }
            return false
        }, timeout: 30)
        XCTAssertTrue(reconnected, "Did not reconnect")
    }
}

private extension XCUIApplication {
    /// The dial's ring: one adjustable element labelled "Volume".
    var adjustableElement: XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == 'Volume'")).firstMatch
    }
}
