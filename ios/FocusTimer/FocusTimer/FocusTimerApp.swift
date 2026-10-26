import SwiftUI
import UIKit
import UserNotifications

@main
struct FocusTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timer = TimerStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timer)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        timer.activate()
                    }
                }
        }
    }
}

// The delegate methods run on the main actor, so the system completion handlers that Swift calls when they
// finish also run on the main thread; UIKit requires that after a notification response.
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NotificationScheduler.configureCategories()
        NotificationScheduler.requestAuthorization()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == NotificationScheduler.startBreakAction else { return }
        let cycleID = NotificationScheduler.cycleID(in: response.notification.request.content.userInfo)
        TimerStore.shared.startBreakFromNotification(cycleID: cycleID)
    }
}
