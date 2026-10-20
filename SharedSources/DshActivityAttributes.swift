import ActivityKit
import Foundation

/// Общий тип для основного приложения (запускает/обновляет Live Activity) и для
/// Widget Extension (только рисует её на экране блокировки / в Dynamic Island).
/// Должен быть в обоих таргетах — см. project.yml (sources этой папки подключены к обоим).
public struct DshActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusText: String
        public var isWaiting: Bool
        public var updatedAt: Date

        public init(statusText: String, isWaiting: Bool, updatedAt: Date = .now) {
            self.statusText = statusText
            self.isWaiting = isWaiting
            self.updatedAt = updatedAt
        }
    }

    public var title: String

    public init(title: String = "dsh") {
        self.title = title
    }
}
