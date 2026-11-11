import Foundation
import UserNotifications

enum NotificationScheduler {
    static let focusIdentifier = "focusComplete"
    static let breakIdentifier = "breakComplete"
    static let focusCategory = "FOCUS_COMPLETE"
    static let breakCategory = "BREAK_COMPLETE"
    nonisolated static let startBreakAction = "START_BREAK"
    nonisolated static let doneAction = "DONE"
    nonisolated static let restartAction = "RESTART"
    /// `userInfo` key holding the cycle ID as a UUID string.
    nonisolated static let cycleIDKey = "cycleID"

    /// The cycle ID a completion notification was scheduled for, or nil if it has none.
    nonisolated static func cycleID(in userInfo: [AnyHashable: Any]) -> UUID? {
        (userInfo[cycleIDKey] as? String).flatMap(UUID.init(uuidString:))
    }

    /// Registers both categories in one call, because setting categories replaces the whole set.
    static func configureCategories() {
        let startBreak = UNNotificationAction(
            identifier: startBreakAction,
            title: "OK",
            options: [.foreground]
        )
        // No options: Restart and Done act in the background without opening the app. Restart comes first,
        // as in the app.
        let restart = UNNotificationAction(identifier: restartAction, title: "Restart", options: [])
        let done = UNNotificationAction(identifier: doneAction, title: "Done", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: focusCategory, actions: [startBreak], intentIdentifiers: []),
            UNNotificationCategory(identifier: breakCategory, actions: [restart, done], intentIdentifiers: []),
        ])
    }

    /// The completion alert for a running phase, or nil for a phase that has none.
    static func content(for phase: TimerStore.Phase, cycleID: UUID?) -> UNMutableNotificationContent? {
        let content = UNMutableNotificationContent()
        content.sound = .default
        if let cycleID {
            content.userInfo = [cycleIDKey: cycleID.uuidString]
        }
        switch phase {
        case .runningA:
            content.title = "Focus complete"
            content.body = "Open the app or choose OK to start Break."
            content.categoryIdentifier = focusCategory
        case .runningB:
            content.title = "Cycle complete"
            content.body = "Choose Restart for another Focus, or Done to finish."
            content.categoryIdentifier = breakCategory
        case .idle, .waitingForAConfirm, .completed:
            return nil
        }
        return content
    }

    /// Asks for permission to alert; returns once the user has answered or the answer is already known.
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Whether the user turned alerts off. A status not yet asked for, or a provisional one, is not denied.
    nonisolated static func isDenied(_ status: UNAuthorizationStatus) -> Bool {
        status == .denied
    }

    /// Whether a failed request should be reported to the user. Denied alerts are not a failure here;
    /// the denied hint covers them.
    nonisolated static func isReportableFailure(_ error: any Error) -> Bool {
        (error as? UNError)?.code != .notificationsNotAllowed
    }
}

protocol NotificationScheduling {
    /// Schedules the completion alert. `onFailure` runs on the main actor, possibly later, if iOS rejects
    /// the request for any reason other than alerts being denied.
    func scheduleCompletion(
        for phase: TimerStore.Phase,
        at deadline: Date,
        now: Date,
        cycleID: UUID?,
        onFailure: @escaping @MainActor () -> Void
    )
    func cancelPendingCompletion(for phase: TimerStore.Phase)
    func cancelAllPendingCompletions()
    /// Removes a completion alert for the phase that is already in Notification Center.
    func removeDeliveredCompletion(for phase: TimerStore.Phase)
    func removeAllDeliveredCompletions()
    /// The current permission to alert, as Settings shows it.
    func authorizationStatus() async -> UNAuthorizationStatus
}

struct SystemNotificationScheduler: NotificationScheduling {
    func scheduleCompletion(
        for phase: TimerStore.Phase,
        at deadline: Date,
        now: Date,
        cycleID: UUID?,
        onFailure: @escaping @MainActor () -> Void
    ) {
        guard let content = NotificationScheduler.content(for: phase, cycleID: cycleID) else { return }
        let identifier = phase == .runningA ? NotificationScheduler.focusIdentifier : NotificationScheduler.breakIdentifier

        let interval = max(1, deadline.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task {
            do {
                try await center.add(request)
            } catch {
                if NotificationScheduler.isReportableFailure(error) {
                    onFailure()
                }
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
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
        case .idle, .waitingForAConfirm, .completed:
            break
        }
    }

    func cancelAllPendingCompletions() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [NotificationScheduler.focusIdentifier, NotificationScheduler.breakIdentifier]
        )
    }

    func removeDeliveredCompletion(for phase: TimerStore.Phase) {
        switch phase {
        case .runningA:
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: [NotificationScheduler.focusIdentifier]
            )
        case .runningB:
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: [NotificationScheduler.breakIdentifier]
            )
        case .idle, .waitingForAConfirm, .completed:
            break
        }
    }

    func removeAllDeliveredCompletions() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [NotificationScheduler.focusIdentifier, NotificationScheduler.breakIdentifier]
        )
    }
}
