import ActivityKit
import Foundation

/// Общий тип для основного приложения (запускает/обновляет Live Activity) и для
/// Widget Extension (только рисует её на экране блокировки / в Dynamic Island).
/// Должен быть в обоих таргетах — см. project.yml (sources этой папки подключены к обоим).
public struct DshActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Полный текст статуса — для экрана блокировки и развёрнутого Dynamic Island.
        public var statusText: String
        /// Короткая версия для свёрнутого (compact) Dynamic Island, когда не идёт
        /// секундомер (idle / ожидание подтверждения) — там места на пару слов.
        public var shortLabel: String
        /// Имя SF Symbol (иконки Apple) под текущий статус, см. toolLabel/runningPresentation.
        public var iconName: String
        /// true — ждём подтверждения/ответа от пользователя (оранжевый акцент).
        public var isWaiting: Bool
        /// true — агент активно работает (думает/пишет код/читает файлы/...), тогда
        /// вместо короткой надписи показываем живой секундомер от startedAt.
        public var isActive: Bool
        /// Момент, с которого считаем секундомер — выставляется один раз при входе
        /// в running и не сбрасывается на каждое обновление detail внутри одной сессии работы.
        public var startedAt: Date

        public init(
            statusText: String,
            shortLabel: String,
            iconName: String,
            isWaiting: Bool,
            isActive: Bool,
            startedAt: Date
        ) {
            self.statusText = statusText
            self.shortLabel = shortLabel
            self.iconName = iconName
            self.isWaiting = isWaiting
            self.isActive = isActive
            self.startedAt = startedAt
        }
    }

    public var title: String

    public init(title: String = "dsh") {
        self.title = title
    }
}
