import XCTest

/// يفتح التطبيق على خادم محلي فيه بيانات تجريبية، ويمر على كل الشاشات ويصوّرها
final class SmokeTests: XCTestCase {
    let api = "http://127.0.0.1:8787"
    override func setUp() { continueAfterFailure = true }

    func app(route: String? = nil, noUpdate: Bool = true, dark: Bool = false) -> XCUIApplication {
        let a = XCUIApplication()
        a.launchEnvironment["ORVEX_API"] = api
        if let r = route { a.launchEnvironment["ORVEX_ROUTE"] = r }
        if noUpdate { a.launchEnvironment["ORVEX_NO_UPDATE"] = "1" }
        if dark { a.launchArguments += ["-orvex.appearance", "dark"] }
        return a
    }
    func shot(_ a: XCUIApplication, _ name: String) {
        let s = XCTAttachment(screenshot: a.screenshot()); s.name = name; s.lifetime = .keepAlways; add(s)
    }
    func log(_ m: String) { print("OrvexReport: " + m) }
    @discardableResult
    func ready(_ a: XCUIApplication) -> Bool {
        let user = a.textFields["username"], tabs = a.tabBars.firstMatch
        for _ in 0..<60 {
            if tabs.exists { return true }
            if user.exists {
                user.tap(); user.typeText("joe")
                let pass = a.secureTextFields["password"]; pass.tap(); pass.typeText("StrongPass1")
                a.buttons["loginBtn"].tap(); log("login")
            }
            if a.buttons["laterBtn"].exists { a.buttons["laterBtn"].tap() }
            usleep(500_000)
        }
        return tabs.exists
    }
    func bad(_ a: XCUIApplication) -> Bool {
        a.staticTexts["الصفحة غير موجودة"].exists || a.staticTexts["تعذّر تحميل هذه الصفحة"].exists || a.staticTexts["غير متاح"].exists
    }

    func test1_LoginAndUpdate() throws {
        let a = app(noUpdate: false); a.launch()
        let user = a.textFields["username"]
        if user.waitForExistence(timeout: 25) {
            shot(a, "01-login")
            user.tap(); user.typeText("joe")
            let pass = a.secureTextFields["password"]; pass.tap(); pass.typeText("StrongPass1")
            a.buttons["loginBtn"].tap()
        }
        if a.buttons["downloadUpdate"].waitForExistence(timeout: 20) {
            sleep(1); shot(a, "02-update"); log("ok update card")
            if a.buttons["laterBtn"].exists { a.buttons["laterBtn"].tap() }
        } else { log("FAIL no update card") }
        XCTAssertTrue(a.tabBars.firstMatch.waitForExistence(timeout: 20))
        sleep(3); shot(a, "03-home")
        a.swipeUp(); sleep(1); shot(a, "04-home-b")
    }

    func test2_Tabs() throws {
        let a = app(); a.launch()
        XCTAssertTrue(ready(a))
        for (i, name) in ["الموقع", "الإحصاءات", "الإدارة"].enumerated() {
            let b = a.tabBars.buttons[name]
            if b.waitForExistence(timeout: 5) {
                b.tap(); sleep(2); shot(a, "1\(i)-tab-\(name)")
                a.swipeUp(); sleep(1); shot(a, "1\(i)-tab-\(name)-b")
            } else { log("FAIL tab \(name)") }
        }
        a.tabBars.buttons["الرئيسية"].tap(); sleep(1)
        let s = a.buttons["searchBtn"].firstMatch
        if s.waitForExistence(timeout: 5) {
            s.tap(); sleep(1)
            let f = a.searchFields.firstMatch
            if f.waitForExistence(timeout: 5) { f.tap(); f.typeText("باقة"); sleep(3); shot(a, "15-search") } else { log("FAIL search field") }
        } else { log("FAIL search button") }
    }

    func test3_Screens() throws {
        let routes = ["gate", "schedule", "plans", "pricing", "form:vip", "sections", "form:intro", "list:counters", "form:goals", "form:gym", "form:train", "faq", "pages", "form:page-about", "links", "texts", "look", "mood", "seo", "mode", "form:maintenance", "geo",
                      "live", "speed", "waitlist", "cast", "casts", "bot", "users", "history", "log", "files", "app-updates", "app-control", "system", "inbox", "notify-send", "settings", "about"]
        for (i, r) in routes.enumerated() {
            let a = app(route: r); a.launch()
            guard ready(a) else { log("FAIL no tabs for \(r)"); continue }
            sleep(3)
            log(bad(a) ? "FAIL screen \(r)" : "ok \(r)")
            let n = String(format: "2%02d-%@", i, r.replacingOccurrences(of: ":", with: "-"))
            shot(a, n)
            a.swipeUp(); sleep(1); shot(a, n + "-b")
            a.terminate()
        }
    }

    func test4_EditAndSave() throws {
        let a = app(route: "gate"); a.launch()
        XCTAssertTrue(ready(a)); sleep(2)
        let st = a.buttons["state-open"]
        if st.waitForExistence(timeout: 5) { st.tap() } else { log("FAIL gate option") }
        let save = a.buttons["saveBtn"]
        if save.waitForExistence(timeout: 5) {
            sleep(1); shot(a, "30-dirty")
            save.tap(); sleep(3); shot(a, "31-saved")
            log(save.exists ? "FAIL still dirty" : "ok saved")
        } else { log("FAIL no save bar") }
        // باقة: فتح أول باقة وتعديل السعر
        let a2 = app(route: "plans"); a2.launch()
        XCTAssertTrue(ready(a2)); sleep(2)
        let first = a2.buttons.matching(NSPredicate(format: "label CONTAINS %@", "اشتراك")).firstMatch
        if first.waitForExistence(timeout: 5) { first.tap(); sleep(2); shot(a2, "32-plan"); a2.swipeUp(); sleep(1); shot(a2, "33-plan-b") } else { log("FAIL plan row") }
    }

    func test5_Dark() throws {
        let a = app(dark: true); a.launch()
        XCTAssertTrue(ready(a)); sleep(3)
        shot(a, "40-dark-home")
        a.tabBars.buttons["الموقع"].tap(); sleep(2); shot(a, "41-dark-site")
        a.tabBars.buttons["الإدارة"].tap(); sleep(2); shot(a, "42-dark-admin")
        let a2 = app(route: "gate", dark: true); a2.launch(); XCTAssertTrue(ready(a2)); sleep(2); shot(a2, "43-dark-gate")
    }

    func test6_UserEditor() throws {
        let a = app(route: "users"); a.launch()
        XCTAssertTrue(ready(a)); sleep(2)
        let add = a.buttons["addUser"]
        if add.waitForExistence(timeout: 5) {
            add.tap(); sleep(2)
            let p = a.buttons["preset-editor"]
            if p.waitForExistence(timeout: 3) { p.tap() }
            sleep(1); shot(a, "50-user-new"); a.swipeUp(); sleep(1); shot(a, "51-user-new-b")
        } else { log("FAIL add user") }
    }
}
