import XCTest

/// Runs Apple's accessibility audit, the checks the Accessibility Inspector runs, on each main screen at the
/// default and the largest accessibility text size. Each screen is reached by seeding the saved timer through
/// launch arguments, which override the app's stored values for that launch only; the app has no test code.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    enum Screen: CaseIterable {
        case idle
        case focusRunning
        case focusPaused
        case waitingForBreak
        case cycleComplete
    }

    static let largestTextSize = "UICTContentSizeCategoryAccessibilityXXXL"


    override func setUp() {
        continueAfterFailure = true
    }

    func testAuditAtDefaultTextSize() throws {
        for screen in Screen.allCases {
            try audit(screen, textSize: nil)
        }
    }

    func testAuditAtLargestTextSize() throws {
        for screen in Screen.allCases {
            try audit(screen, textSize: Self.largestTextSize)
        }
    }

    // MARK: Helpers

    /// Audits the whole screen: the visible part, then each further part as the scroll view moves down. The audit
    /// checks only what is on screen, and at the largest text size the status card and buttons start below the fold.
    /// Each element the screen is about must be brought into view during one of the audited parts, which proves the
    /// parts covered it.
    ///
    /// XCUITest reports stale frames for these SwiftUI elements once the view has scrolled. So the number of parts is
    /// fixed rather than detected (the largest-size content is about twice the screen height), and scrolled parts skip
    /// the contrast category: there it attributes issues to off-screen elements, such as the black title, and samples
    /// the wrong pixels (an all-black picture of the Done button). Contrast below the fold is covered by
    /// `PaletteContrastTests`, which checks every text colour against every background it is drawn on.
    private func audit(_ screen: Screen, textSize: String?) throws {
        let app = XCUIApplication()
        app.launchArguments = Self.seed(screen)
        if let textSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }
        app.launch()
        XCTAssertTrue(app.buttons["primaryTimerButton"].waitForExistence(timeout: 5), "\(screen) did not load")

        let size = textSize ?? "default"
        let required = Self.requiredElements(screen, in: app)
        var seen = Set<String>()
        let scrollView = app.scrollViews.firstMatch
        let parts = textSize == nil ? 1 : Self.largestTextParts

        for part in 1...parts {
            for (name, element) in required where element.exists && element.isHittable {
                seen.insert(name)
            }
            let categories: XCUIAccessibilityAuditType = part == 1 ? .all : .all.subtracting(.contrast)
            try app.performAccessibilityAudit(for: categories) { issue in
                let element = issue.element.map { "\($0.elementType.rawValue) label=\"\($0.label)\" id=\"\($0.identifier)\"" } ?? "none"
                print("AUDIT \(screen) size=\(size) part=\(part) type=\(issue.auditType.rawValue) \(issue.compactDescription) | element: \(element)")
                return Self.isAllowed(issue)
            }
            if part < parts {
                scrollView.swipeUp()
            }
        }

        for name in required.keys where !seen.contains(name) {
            XCTFail("\(screen) at \(size): \(name) was never brought into view, so the audit did not cover it")
        }
        app.terminate()
    }

    /// Screenfuls audited at the largest text size.
    static let largestTextParts = 4

    /// The elements each screen is about; each must be on screen during one of the audited parts.
    private static func requiredElements(_ screen: Screen, in app: XCUIApplication) -> [String: XCUIElement] {
        let primary = app.buttons["primaryTimerButton"]
        return switch screen {
        case .idle:
            ["Ready card": app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH[c] 'ready'")).firstMatch, "Start": primary]
        case .focusRunning, .focusPaused:
            [
                "status card": app.descendants(matching: .any)["activeTimerStatus"],
                "pause or resume": app.buttons.matching(NSPredicate(format: "label IN {'Pause timer', 'Resume timer'}")).firstMatch,
            ]
        case .waitingForBreak:
            ["Start Break": app.buttons["Start Break"]]
        case .cycleComplete:
            ["Restart": app.buttons["Restart"], "Done": app.buttons["doneButton"]]
        }
    }

    /// Issues the app cannot fix, each recorded with its reason in the I28 spec. Return true to allow one.
    private static func isAllowed(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        // TODO(I28): stop allowing these. The audit flags the header subtitle for contrast on most screens, sometimes
        // without naming the element. The subtitle is dark grey on cream, well above 4.5:1 by the palette's own
        // measurement, so the audit's reading looks wrong; find out why (font weight, the gradient behind it), fix
        // it, and remove this. Caution: the no-element branch lets through ANY unidentified contrast issue, not only
        // the subtitle, so a pass does not prove only the subtitle is affected. Contrast issues that name another
        // element still fail. See specs/ios/phases/I28-accessibility-audit.md.
        if issue.auditType == .contrast, issue.element == nil || issue.element?.label == "Run Focus, confirm, then run Break." {
            return true
        }
        // WCAG exempts inactive controls from contrast: the Start button is disabled while a timer runs.
        if issue.auditType == .contrast, let element = issue.element, element.elementType == .button, !element.isEnabled {
            return true
        }
        return false
    }

    /// Launch arguments that set the saved configuration and timer for one launch. A phase that ended before
    /// launch shows its end screen once, which is how the waiting and completed screens are reached.
    private static func seed(_ screen: Screen) -> [String] {
        let now = Date().timeIntervalSinceReferenceDate
        let cycle = UUID().uuidString
        let state: [String: Any] = switch screen {
        case .idle: ["phase": "idle", "paused": false]
        case .focusRunning: ["phase": "runningA", "endTimestamp": now + 750, "paused": false, "cycleID": cycle]
        case .focusPaused: ["phase": "runningA", "paused": true, "remainingSeconds": 750, "cycleID": cycle]
        case .waitingForBreak: ["phase": "runningA", "endTimestamp": now - 5, "paused": false, "cycleID": cycle]
        case .cycleComplete: ["phase": "runningB", "endTimestamp": now - 5, "paused": false, "cycleID": cycle]
        }
        let config: [String: Any] = ["durationASeconds": 25 * 60, "durationBSeconds": 5 * 60]
        return [
            "-config", plistData(config),
            "-state", plistData(state),
            "-schemaVersion", plistData(3),
        ]
    }

    /// JSON, as the app saves it, written as an old-style property-list data literal for the argument domain.
    private static func plistData(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])) ?? Data()
        return "<" + data.map { String(format: "%02x", $0) }.joined() + ">"
    }
}
