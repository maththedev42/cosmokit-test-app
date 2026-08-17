import SwiftUI
import UserNotifications

@main
struct CosmoKitTestAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Something for the Log Stream tool to catch the moment the app starts,
        // so an empty stream means the stream is broken rather than idle.
        TestLog.lifecycle.notice("CosmoKitTestApp launched, subsystem \(TestLog.subsystem, privacy: .public)")
        // simctl push only renders a banner if the app has been granted
        // notification authorization — request it on first launch so the
        // CosmoKit push tool can be tested end to end.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        post(notification)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        post(response.notification)
        completionHandler()
    }

    private func post(_ notification: UNNotification) {
        NotificationCenter.default.post(
            name: .cosmoKitPushReceived,
            object: nil,
            userInfo: [
                "title": notification.request.content.title,
                "body": notification.request.content.body,
                "userInfo": notification.request.content.userInfo
            ]
        )
    }
}

extension Notification.Name {
    static let cosmoKitPushReceived = Notification.Name("CosmoKitTestApp.pushReceived")
}
