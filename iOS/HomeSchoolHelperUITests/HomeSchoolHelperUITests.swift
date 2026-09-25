import Foundation
import XCTest

final class HomeSchoolHelperUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["HSH_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["HSH_UI_TEST_AUTH_MODE"] = "authenticated"
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testSignedOutUserCannotAccessSchoolAndSignupRequiresMatchingPassword() {
        app.terminate()
        app.launchEnvironment["HSH_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment.removeValue(forKey: "HSH_UI_TEST_AUTH_MODE")
        app.launch()

        XCTAssertTrue(app.textFields["loginEmail"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        XCTAssertFalse(app.tabBars.buttons["Family"].exists)
        XCTAssertFalse(app.buttons["loginSubmit"].isEnabled)
        tap("loginToggleMode", in: app.buttons)
        enter("parent@example.com", into: app.textFields["loginEmail"])
        enter("long-password", into: app.secureTextFields["loginPassword"])
        enter("mismatch", into: app.secureTextFields["loginPasswordConfirmation"])
        XCTAssertFalse(app.buttons["loginSubmit"].isEnabled)
        enter("long-password", into: app.secureTextFields["loginPasswordConfirmation"])
        XCTAssertTrue(app.buttons["loginSubmit"].isEnabled)
        XCTAssertFalse(app.tabBars.buttons["Records"].exists)
        attachScreenshot(named: "signup-validation")
    }

    func testIndependentFlexibleProgressRecordsAndPersistence() throws {
        addLearner(name: "Ada", grade: "4")
        addLearner(name: "Ben", grade: "2")
        buildSharedUndatedSequence()

        app.tabBars.buttons["Today"].tap()
        tap("assignment-Ada-Lesson One", in: app.buttons)
        tap("assignmentStatusPicker", in: app.buttons)
        tap("Completed", in: app.buttons)
        tap("saveAssignmentStatus", in: app.buttons)

        reveal(app.buttons["assignment-Ada-Lesson Two"])
        reveal(app.buttons["assignment-Ben-Lesson One"])
        XCTAssertFalse(app.buttons["assignment-Ada-Lesson One"].exists)

        app.tabBars.buttons["Records"].tap()
        XCTAssertTrue(app.staticTexts["0 learner-days"].waitForExistence(timeout: 2))
        recordAttendanceForAda(minutes: "120")
        recordAttendanceForAda(minutes: "150")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "2h 30m")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 learner-days"].exists)
        tap("openAttendance", in: app.buttons)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "2h 30m")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(attendanceEntries(for: "Ada").count, 1)
        tap("Done", in: app.buttons)

        logRetrospectiveActivityForBen()
        XCTAssertTrue(app.staticTexts["Museum visit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ben · \(shortDate(daysBeforeToday: 7)) · 30m"].exists)

        app.terminate()
        app.launch()

        app.tabBars.buttons["Family"].tap()
        XCTAssertTrue(app.staticTexts["Ada"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ben"].exists)
        app.tabBars.buttons["Records"].tap()
        XCTAssertTrue(app.staticTexts["Museum visit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 learner-days"].exists)
        tap("openAttendance", in: app.buttons)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "2h 30m")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(attendanceEntries(for: "Ada").count, 1)
        tap("Done", in: app.buttons)
        app.tabBars.buttons["Today"].tap()
        reveal(app.buttons["assignment-Ada-Lesson Two"])
        reveal(app.buttons["assignment-Ben-Lesson One"])
        XCTAssertEqual(app.buttons["assignment-Ben-Lesson One"].label, "Lesson One for Ben, Planned")
    }

    func testLargeTextDarkModeAccessibilitySmoke() throws {
        app.terminate()
        app.launchEnvironment["HSH_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["HSH_UI_TEST_AUTH_MODE"] = "authenticated"
        app.launchEnvironment["HSH_UI_TEST_DARK_MODE"] = "1"
        app.launchEnvironment["HSH_UI_TEST_LARGE_TEXT"] = "1"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Plan"].exists)
        XCTAssertTrue(app.tabBars.buttons["Records"].exists)
        XCTAssertTrue(app.tabBars.buttons["Family"].exists)
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        attachScreenshot(named: "large-text-dark-today")

        app.tabBars.buttons["Plan"].tap()
        attachScreenshot(named: "large-text-dark-plan")
        app.tabBars.buttons["Records"].tap()
        attachScreenshot(named: "large-text-dark-records")

        app.tabBars.buttons["Family"].tap()
        attachScreenshot(named: "large-text-dark-family")
        reveal(app.buttons["addStudent"])
        addLearner(name: "Rae", grade: "5")
        reveal(app.staticTexts["Rae"], direction: .down)
    }

    private func addLearner(name: String, grade: String) {
        app.tabBars.buttons["Family"].tap()
        tap("addStudent", in: app.buttons)
        enter(name, into: app.textFields["studentName"])
        enter(grade, into: app.textFields["studentGrade"])
        tap("saveStudent", in: app.buttons)
        reveal(app.staticTexts[name], direction: .down)
    }

    private func buildSharedUndatedSequence() {
        app.tabBars.buttons["Plan"].tap()
        tap("addCourse", in: app.buttons)
        enter("Shared Math", into: app.textFields["courseTitle"])
        let lessons = app.textViews["lessonTitles"]
        XCTAssertTrue(lessons.waitForExistence(timeout: 2))
        lessons.tap()
        lessons.typeText("Lesson One\nLesson Two")
        app.swipeUp()
        setSwitch("Ada", enabled: true)
        setSwitch("Ben", enabled: true)
        setSwitch("datedLessonSchedule", enabled: false)
        tap("saveCourse", in: app.buttons)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["saveCourse"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 3), .completed, "Course form did not save")
        reveal(app.buttons["assignment-Ada-Lesson One"])
        reveal(app.buttons["assignment-Ben-Lesson One"])
        XCTAssertEqual(app.buttons["assignment-Ben-Lesson One"].label, "Lesson One for Ben, Planned")
    }

    private func recordAttendanceForAda(minutes: String) {
        app.tabBars.buttons["Records"].tap()
        tap("openAttendance", in: app.buttons)
        tap("attendanceLearner", in: app.buttons)
        tap("Ada", in: app.buttons)
        enter(minutes, into: app.textFields["attendanceMinutes"])
        tap("confirmAttendance", in: app.buttons)
        tap("Done", in: app.buttons)
    }

    private func attendanceEntries(for learner: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "attendanceEntry-\(learner)-")
        )
    }

    private func logRetrospectiveActivityForBen() {
        app.tabBars.buttons["Records"].tap()
        tap("addActivity", in: app.buttons)
        enter("Museum visit", into: app.textFields["activityTitle"])
        selectDate(daysBeforeToday: 7, in: app.datePickers["activityDay"])
        setSwitch("Ben", enabled: true)
        tap("saveActivity", in: app.buttons)
    }

    private func selectDate(daysBeforeToday: Int, in datePicker: XCUIElement) {
        XCTAssertTrue(datePicker.waitForExistence(timeout: 2))
        let target = Calendar.current.date(byAdding: .day, value: -daysBeforeToday, to: Date())!
        datePicker.tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d"
        let targetButton = app.buttons[formatter.string(from: target)]

        let calendar = Calendar.current
        let thisMonth = calendar.dateInterval(of: .month, for: Date())!.start
        let targetMonth = calendar.dateInterval(of: .month, for: target)!.start
        let monthDifference = calendar.dateComponents([.month], from: thisMonth, to: targetMonth).month ?? 0
        if monthDifference < 0 {
            for _ in 0 ..< abs(monthDifference) {
                tap("Previous Month", in: app.buttons)
            }
        }
        XCTAssertTrue(targetButton.waitForExistence(timeout: 2), "Calendar did not expose \(formatter.string(from: target))")
        targetButton.tap()
    }

    private func shortDate(daysBeforeToday: Int) -> String {
        let target = Calendar.current.date(byAdding: .day, value: -daysBeforeToday, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: target)
    }

    private func enter(_ value: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 32))
        field.typeText(value)
    }

    private func tap(_ identifier: String, in query: XCUIElementQuery) {
        let element = query[identifier]
        reveal(element)
        element.tap()
    }

    private func setSwitch(_ identifier: String, enabled: Bool) {
        let row = app.switches[identifier]
        reveal(row)
        // SwiftUI exposes a labeled row and a nested UISwitch. Tapping the
        // row's center can hit inert label space rather than the control.
        let control = row.switches.firstMatch.exists ? row.switches.firstMatch : row
        reveal(control)
        let expected = enabled ? "1" : "0"
        if control.value as? String != expected { control.tap() }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed, "Switch \(identifier) did not change")
    }

    private enum ScrollDirection { case up, down }

    /// SwiftUI List virtualizes offscreen rows; waiting alone cannot reveal them.
    private func reveal(_ element: XCUIElement, direction: ScrollDirection = .up,
                        file: StaticString = #filePath, line: UInt = #line) {
        let directions: [ScrollDirection] = direction == .up ? [.up, .down] : [.down, .up]
        for searchDirection in directions {
            for attempt in 0...6 {
                if element.exists && element.isHittable { return }
                if attempt < 6 {
                    if searchDirection == .up { app.swipeUp() } else { app.swipeDown() }
                }
            }
        }
        print(app.debugDescription)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Unreachable element hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail("Element not reachable: \(element)", file: file, line: line)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
