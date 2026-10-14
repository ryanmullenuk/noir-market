import XCTest

/// Drives the real UI through the core loop: start, trade, travel, survive the night.
final class PlaythroughTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testStartTradeTravelAndSurviveAWeek() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetSave", "-musicOff", "-noGameCenter"]
        app.launch()

        let newGame = button(app, "New Game")
        if !newGame.waitForExistence(timeout: 8) { print("TREE\n" + app.debugDescription) }
        XCTAssertTrue(newGame.exists)
        sleep(4) // let the title and buttons fade in
        newGame.tap()

        let begin = button(app, "Begin")
        XCTAssertTrue(begin.waitForExistence(timeout: 4))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText("Sam Spade\n")
        begin.tap()

        // Buy the cheapest thing we can afford.
        let stay = app.buttons["stay"]
        XCTAssertTrue(stay.waitForExistence(timeout: 5))
        for name in ["Kat", "Mushrooms", "Pot", "Peyote", "LSD"] {
            let row = app.descendants(matching: .any)["good-\(name)"]
            guard row.waitForExistence(timeout: 2) else { continue }
            row.tap()
            let max = app.buttons["tradeMax"]
            if max.waitForExistence(timeout: 2) {
                max.tap()
                app.buttons["tradeAction"].tap()
                break
            }
            app.swipeDown(velocity: .fast)
        }
        attach(app, "after-buy")

        // Travel to Manchester.
        app.buttons["dock-travel"].tap()
        let manchester = button(app, "Manchester")
        XCTAssertTrue(manchester.waitForExistence(timeout: 4))
        manchester.tap()
        let go = button(app, "Go to Manchester")
        XCTAssertTrue(go.waitForExistence(timeout: 3))
        go.tap()
        handleNight(app)
        attach(app, "manchester")

        // Stay a few nights, handling whatever the street throws at us.
        for _ in 0..<6 {
            XCTAssertTrue(stay.waitForExistence(timeout: 5))
            stay.tap()
            handleNight(app)
        }
        attach(app, "week-one")
        XCTAssertTrue(stay.exists)

        // Panels open and close.
        for panel in ["stash", "money", "shop", "street"] {
            app.buttons["dock-\(panel)"].tap()
            sleep(1)
            attach(app, panel)
            app.swipeDown(velocity: .fast)
            sleep(1)
        }
    }

    @MainActor
    private func handleNight(_ app: XCUIApplication) {
        for _ in 0..<8 {
            if button(app, "Disconnect").waitForExistence(timeout: 2) { button(app, "Disconnect").tap(); continue }
            if button(app, "Respond").exists { button(app, "Respond").tap(); continue }
            if button(app, "Carry on").exists { button(app, "Carry on").tap(); continue }
            // An encounter: take the first enabled option.
            let options = app.buttons.allElementsBoundByIndex.filter { $0.isEnabled && $0.isHittable && !$0.label.isEmpty }
            if app.staticTexts["Police Stop"].exists || app.staticTexts["Trouble"].exists || app.staticTexts["Customs"].exists || app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'Lads'")).count > 0 {
                attach(app, "encounter")
                options.first?.tap()
                continue
            }
            if app.buttons["stay"].exists { return }
        }
    }

    @MainActor
    private func button(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
