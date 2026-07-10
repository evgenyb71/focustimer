import Foundation
import UserNotifications

enum NotificationScheduler {
    static let focusIdentifier = "focusComplete"
    static let breakIdentifier = "breakComplete"
    static let focusCategory = "FOCUS_COMPLETE"
    static let startBreakAction = "START_BREAK"

    static func configureCategories() {
        let action = UNNotificationAction(
            identifier: startBreakAction,
            title: "OK",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: focusCategory,
            actions: [action],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleCompletion(for phase: TimerStore.Phase, at deadline: Date) {
        let identifier: String
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch phase {
        case .runningA:
            identifier = focusIdentifier
            content.title = "Focus Timer complete"
            content.body = "Tap OK to start Break Timer."
            content.categoryIdentifier = focusCategory
        case .runningB:
            identifier = breakIdentifier
            content.title = "Break Timer complete"
            content.body = "Sequence finished."
        case .idle, .waitingForAConfirm:
            return
        }

        let interval = max(1, deadline.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    static func cancelPendingCompletion(for phase: TimerStore.Phase) {
        switch phase {
        case .runningA:
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusIdentifier])
        case .runningB:
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [breakIdentifier])
        case .idle, .waitingForAConfirm:
            break
        }
    }

    static func cancelAllPendingCompletions() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [focusIdentifier, breakIdentifier]
        )
    }
}
