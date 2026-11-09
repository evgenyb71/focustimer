import Foundation
import Testing
import UserNotifications
@testable import FocusTimer

/// The completion alert content, built without the system notification center.
@MainActor
struct NotificationSchedulerTests {
    @Test func focusAlertOffersOKWithTheNewWording() throws {
        let cycleID = UUID()

        let content = try #require(NotificationScheduler.content(for: .runningA, cycleID: cycleID))

        #expect(content.title == "Focus complete")
        #expect(content.body == "Open the app or choose OK to start Break.")
        #expect(content.categoryIdentifier == NotificationScheduler.focusCategory)
        #expect(NotificationScheduler.cycleID(in: content.userInfo) == cycleID)
    }

    @Test func breakAlertOffersDoneWithTheNewWording() throws {
        let cycleID = UUID()

        let content = try #require(NotificationScheduler.content(for: .runningB, cycleID: cycleID))

        #expect(content.title == "Cycle complete")
        #expect(content.body == "Choose Done to finish, or open the app to restart.")
        #expect(content.categoryIdentifier == NotificationScheduler.breakCategory)
        #expect(NotificationScheduler.cycleID(in: content.userInfo) == cycleID)
    }

    @Test func theTwoAlertsUseDifferentCategoriesAndActions() {
        #expect(NotificationScheduler.focusCategory != NotificationScheduler.breakCategory)
        #expect(NotificationScheduler.startBreakAction != NotificationScheduler.doneAction)
    }

    @Test func alertWithoutACycleIDCarriesNone() throws {
        let content = try #require(NotificationScheduler.content(for: .runningB, cycleID: nil))

        #expect(NotificationScheduler.cycleID(in: content.userInfo) == nil)
    }

    @Test(arguments: [TimerStore.Phase.idle, .waitingForAConfirm, .completed])
    func phasesWithoutAnAlertHaveNoContent(_ phase: TimerStore.Phase) {
        #expect(NotificationScheduler.content(for: phase, cycleID: UUID()) == nil)
    }
}
