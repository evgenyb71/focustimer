import Foundation
import UserNotifications

enum NotificationScheduler {
    static let focusIdentifier = "focusComplete"
    static let breakIdentifier = "breakComplete"
    static let focusCategory = "FOCUS_COMPLETE"
    nonisolated static let startBreakAction = "START_BREAK"
    /// `userInfo` key holding the cycle ID as a UUID string.
    nonisolated static let cycleIDKey = "cycleID"

    /// The cycle ID a completion notification was scheduled for, or nil if it has none.
    nonisolated static func cycleID(in userInfo: [AnyHashable: Any]) -> UUID? {
        (userInfo[cycleIDKey] as? String).flatMap(UUID.init(uuidString:))
    }

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
}

protocol NotificationScheduling {
    func scheduleCompletion(for phase: TimerStore.Phase, at deadline: Date, now: Date, cycleID: UUID?)
    func cancelPendingCompletion(for phase: TimerStore.Phase)
    func cancelAllPendingCompletions()
}

struct SystemNotificationScheduler: NotificationScheduling {
    func scheduleCompletion(for phase: TimerStore.Phase, at deadline: Date, now: Date, cycleID: UUID?) {
        let identifier: String
        let content = UNMutableNotificationContent()
        content.sound = .default
        if let cycleID {
            content.userInfo = [NotificationScheduler.cycleIDKey: cycleID.uuidString]
        }

        switch phase {
        case .runningA:
            identifier = NotificationScheduler.focusIdentifier
            content.title = "Focus Timer complete"
            content.body = "Tap OK to start Break Timer."
            content.categoryIdentifier = NotificationScheduler.focusCategory
        case .runningB:
            identifier = NotificationScheduler.breakIdentifier
            content.title = "Break Timer complete"
            content.body = "Sequence finished."
        case .idle, .waitingForAConfirm:
            return
        }

        let interval = max(1, deadline.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    func cancelPendingCompletion(for phase: TimerStore.Phase) {
        switch phase {
        case .runningA:
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [NotificationScheduler.focusIdentifier]
            )
        case .runningB:
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [NotificationScheduler.breakIdentifier]
            )
        case .idle, .waitingForAConfirm:
            break
        }
    }

    func cancelAllPendingCompletions() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [NotificationScheduler.focusIdentifier, NotificationScheduler.breakIdentifier]
        )
    }
}
