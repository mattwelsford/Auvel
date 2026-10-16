import XCTest

/// End to end against the real Mac app running on the same machine (CI job "Pairing end to end").
/// The Mac app is launched with `-AuvelE2EPasskey 123456`, a debug-only hook that opens pairing with a fixed code.
/// Skipped unless TEST_RUNNER_AUVEL_E2E_MAC_NAME is set, so normal test runs never touch a real Mac.
@MainActor
final class RealMacUITests: XCTestCase {
    private var app: XCUIApplication!
    private var macName = ""

    override func setUp() async throws {
        continueAfterFailure = false
        guard let name = ProcessInfo.processInfo.environment["AUVEL_E2E_MAC_NAME"], !name.isEmpty else {
            throw XCTSkip("No real Mac configured")
        }
        macName = name
        app = XCUIApplication()
        app.launchArguments = ["-AuvelResetForUITests"]
        app.launch()
    }

    override func tearDown() async throws {
        app?.terminate()
    }

    func testPairAndConnectToRealMac() {
        app.buttons["It's Installed"].tap()
        let next = app.buttons["Continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        let row = app.buttons[macName]
        XCTAssertTrue(row.waitForExistence(timeout: 30), "Real Mac not discovered over Bonjour")
        row.tap()

        app.typeText("123456")
        let open = app.buttons["Open Remote"]
        XCTAssertTrue(open.waitForExistence(timeout: 15), "Pairing did not complete. \(screen("pairing"))")
        open.tap()

        // The step hardware testing reported failing: the TLS-PSK session after pairing.
        let play = app.buttons["Play or pause"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        let deadline = Date().addingTimeInterval(20)
        while !play.isEnabled, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(play.isEnabled, "Remote did not connect to the Mac after pairing. \(screen("remote"))")
    }

    /// Attaches a screenshot and returns the visible text, so the CI log shows what the app showed.
    private func screen(_ name: String) -> String {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return "Screen shows: " + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }
}
