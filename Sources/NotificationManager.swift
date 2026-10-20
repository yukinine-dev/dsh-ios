import Foundation
import UserNotifications

/// Локальные уведомления — без APNs/сертификата, работают пока приложение живо
/// (открыто или недавно свёрнуто). Для "пришло уведомление, пока телефон лежал полчаса"
/// нужен настоящий push — см. README.
enum NotificationManager {
    /// Без этого делегата iOS молча проглатывает уведомление, пока приложение открыто
    /// (foreground) — баннер просто не показывается. Это и выглядело как "уведомления
    /// не работают", хотя они долетали, просто без UI. willPresent явно просит показать
    /// баннер/звук даже на переднем плане.
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound, .list])
        }
    }

    private static let delegate = Delegate()

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().delegate = delegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// delay > 0 — доставить не сразу, а через N секунд (удобно для теста: успеть
    /// свернуть приложение и убедиться, что уведомление реально показывается).
    static func fire(title: String, body: String, delay: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger: UNNotificationTrigger? = delay > 0
            ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            : nil

        let request = UNNotificationRequest(
            identifier: "dsh-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
