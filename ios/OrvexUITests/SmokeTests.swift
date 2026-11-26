import XCTest

/// يفتح التطبيق على سيرفر محلي فيه بيانات تجريبية، يسجّل دخول، ويمر على كل الصفحات ويصوّرها
final class SmokeTests: XCTestCase {
    let api = "http://127.0.0.1:8787"
    override func setUp() { continueAfterFailure = true }

    func app(route: String? = nil, noUpdate: Bool = true, scheme: String? = nil) -> XCUIApplication {
        let a = XCUIApplication()
        a.launchEnvironment["ORVEX_API"] = api
        if let r = route { a.launchEnvironment["ORVEX_ROUTE"] = r }
        if noUpdate { a.launchEnvironment["ORVEX_NO_UPDATE"] = "1" }
        if let s = scheme { a.launchArguments += ["-AppleInterfaceStyle", s] }
        return a
    }
    func shot(_ a: XCUIApplication, _ name: String) {
        let s = XCTAttachment(screenshot: a.screenshot()); s.name = name; s.lifetime = .keepAlways; add(s)
    }
    func log(_ m: String) { print("OrvexReport: " + m) }
    /// يسجّل دخول إذا طلعت شاشة الدخول، ويسد بطاقة التحديث إذا طلعت
    @discardableResult
    func ready(_ a: XCUIApplication) -> Bool {
        let user = a.textFields["username"], tabs = a.tabBars.firstMatch
        for _ in 0..<50 {
            if tabs.exists { return true }
            if user.exists {
                user.tap(); user.typeText("joe")
                let pass = a.secureTextFields["password"]; pass.tap(); pass.typeText("StrongPass1")
                a.buttons["loginBtn"].tap()
                log("relogin")
            }
            if a.buttons["بعدين"].exists { a.buttons["بعدين"].tap() }
            usleep(500_000)
        }
        return tabs.exists
    }

    func test1_LoginAndUpdate() throws {
        let a = app(noUpdate: false)
        a.launch()
        let user = a.textFields["username"]
        if user.waitForExistence(timeout: 25) {
            shot(a, "01-login")
            user.tap(); user.typeText("joe")
            let pass = a.secureTextFields["password"]
            pass.tap(); pass.typeText("StrongPass1")
            a.buttons["loginBtn"].tap()
        }
        let dl = a.buttons["downloadUpdate"]
        if dl.waitForExistence(timeout: 20) {
            shot(a, "02-update-card")
            log("update card shown")
            if a.buttons["بعدين"].exists { a.buttons["بعدين"].tap() } else { a.swipeDown(velocity: .fast) }
        } else { log("FAIL no update card") }
        XCTAssertTrue(a.tabBars.firstMatch.waitForExistence(timeout: 20), "tabs")
        sleep(2)
        shot(a, "03-home")
        a.swipeUp(); sleep(1); shot(a, "04-home-bottom")
    }

    func test2_Tabs() throws {
        let a = app(); a.launch()
        XCTAssertTrue(ready(a))
        for (i, name) in ["الموقع", "الزوار", "التيليجرام", "المزيد"].enumerated() {
            let b = a.tabBars.buttons[name]
            if b.waitForExistence(timeout: 5) { b.tap(); sleep(2); shot(a, "1\(i)-tab-\(name)") } else { log("FAIL tab \(name)") }
        }
        // البحث
        let s = a.tabBars.buttons.element(boundBy: a.tabBars.buttons.count - 1)
        s.tap(); sleep(1)
        let f = a.searchFields.firstMatch
        if f.waitForExistence(timeout: 5) { f.tap(); f.typeText("باقة"); sleep(3); shot(a, "15-search") } else { log("FAIL search field") }
    }

    func test3_Screens() throws {
        let routes = ["gate", "mode", "plans", "content", "texts", "mood", "look", "geo", "advanced", "live", "speed", "waitlist", "cast", "botmsgs", "inbox", "notify-send", "files", "users", "monitor", "history", "log", "app-updates", "app-control", "widgets", "settings", "system", "account", "about"]
        for (i, r) in routes.enumerated() {
            let a = app(route: r); a.launch()
            guard ready(a) else { log("FAIL no tabs for \(r)"); continue }
            sleep(3)
            if a.staticTexts["الصفحة غير موجودة"].exists || a.staticTexts["ما انفتحت الصفحة"].exists { log("FAIL screen \(r) error") } else { log("ok \(r)") }
            shot(a, String(format: "2%02d-%@", i, r))
            a.swipeUp(); sleep(1)
            shot(a, String(format: "2%02d-%@-b", i, r))
            a.terminate()
        }
    }

    func test4_EditAndSave() throws {
        let a = app(route: "gate"); a.launch()
        XCTAssertTrue(ready(a))
        sleep(2)
        let soon = a.buttons.matching(NSPredicate(format: "label CONTAINS %@", "تشويق")).firstMatch
        if soon.waitForExistence(timeout: 5) { soon.tap() } else { log("FAIL gate option") }
        let save = a.buttons["saveBtn"]
        if save.waitForExistence(timeout: 5) {
            shot(a, "30-dirty")
            save.tap(); sleep(3)
            shot(a, "31-saved")
            log(save.exists ? "FAIL still dirty" : "ok saved")
        } else { log("FAIL no save bar") }
    }

    func test5_DarkLight() throws {
        let a = app(route: "settings"); a.launch()
        XCTAssertTrue(ready(a))
        sleep(2)
        for th in ["mist", "paper", "iraqfit", "obsidian"] {
            let b = a.buttons["theme-\(th)"]
            if b.waitForExistence(timeout: 3) { b.tap(); sleep(1); shot(a, "40-theme-\(th)") } else { log("FAIL theme \(th)") }
        }
        let home = a.tabBars.buttons["الرئيسية"]
        if home.exists { home.tap(); sleep(1); shot(a, "45-home-obsidian") }
    }

    func test6_iPadLike() throws {
        let a = app(route: "stats"); a.launch()
        XCTAssertTrue(ready(a))
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2); shot(a, "50-landscape-stats")
        XCUIDevice.shared.orientation = .portrait
    }
}
