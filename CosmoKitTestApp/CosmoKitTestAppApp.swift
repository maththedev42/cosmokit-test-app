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
        // E2E-03a: start clean when asked, before anything can read a receipt.
        Receipts.resetIfNeeded()
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

    /// The only receipt path a macOS test can rely on for silent pushes:
    /// `content-available: 1` arrives here without user-notification
    /// permission being granted.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let aps = userInfo["aps"] as? [String: Any] {
            Receipts.push(aps: aps)
        }
        completionHandler(.newData)
    }

    private func post(_ notification: UNNotification) {
        if let aps = notification.request.content.userInfo["aps"] as? [String: Any] {
            Receipts.push(aps: aps)
        }
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
