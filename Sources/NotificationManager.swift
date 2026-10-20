import Foundation
import UserNotifications

/// Локальные уведомления — без APNs/сертификата, работают пока приложение живо
/// (открыто или недавно свёрнуто). Для "пришло уведомление, пока телефон лежал полчаса"
/// нужен настоящий push — см. README.
enum NotificationManager {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func fire(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dsh-\(UUID().uuidString)",
            content: content,
            trigger: nil // доставить сразу
        )
        UNUserNotificationCenter.current().add(request)
    }
}
