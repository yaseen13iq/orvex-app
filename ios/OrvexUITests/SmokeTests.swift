import XCTest

final class SmokeTests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["أورفيكس"].waitForExistence(timeout: 20))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "launch"; shot.lifetime = .keepAlways; add(shot)
    }
}
