import ActivityKit
import Foundation

/// Следит за DshEventsClient.state и ведёт ровно одну Live Activity + локальные уведомления
/// на значимых переходах. Работает без APNs — только локально, значит обновляется, пока
/// приложение живёт (открыто/недавно свёрнуто); см. README про ограничение.
@MainActor
final class LiveActivityManager: ObservableObject {
    private var activity: Activity<DshActivityAttributes>?
    private var previous: DshState = .disconnected
    private var endWorkItem: DispatchWorkItem?

    /// Момент входа в running — держим его, пока агент не станет idle/disconnected,
    /// чтобы секундомер в Dynamic Island считал "сколько работает" целиком, а не
    /// сбрасывался на каждое изменение detail (думает -> пишет код -> ...).
    private var runningStartedAt: Date?

    func handle(_ state: DshState) {
        defer { previous = state }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        switch state {
        case .disconnected:
            runningStartedAt = nil
            endActivity()

        case .idle:
            runningStartedAt = nil
            apply(statusText: "Свободен", shortLabel: "Готов", iconName: "checkmark.circle.fill", isWaiting: false, isActive: false)
            if case .running = previous {
                NotificationManager.fire(title: "dsh", body: "Готово")
            }
            scheduleEnd(after: 15)

        case .running(let detail):
            endWorkItem?.cancel()
            if runningStartedAt == nil { runningStartedAt = .now }
            let presentation = runningPresentation(for: detail)
            apply(statusText: presentation.text, shortLabel: presentation.short, iconName: presentation.icon, isWaiting: false, isActive: true)

        case .waitingApproval(let text):
            endWorkItem?.cancel()
            let icon = text.hasPrefix("Агент") ? "questionmark.circle.fill" : "exclamationmark.triangle.fill"
            apply(statusText: text, shortLabel: "Ждёт", iconName: icon, isWaiting: true, isActive: false)
            if previous != state {
                NotificationManager.fire(title: "dsh — нужно подтверждение", body: text)
            }
        }
    }

    /// Текст/короткая подпись/иконка под running-detail из DshEventsClient. Детали там —
    /// best-effort строки (см. activityDetail/toolLabel), так что сверяем по подстроке,
    /// а не строгим enum-ом — незнакомый detail просто падает в общий "Думает".
    private func runningPresentation(for detail: String?) -> (text: String, short: String, icon: String) {
        guard let detail else { return ("Думает…", "Думает", "brain.head.profile") }
        switch detail {
        case "Пишет код":
            return (detail, "Код", "chevron.left.forwardslash.chevron.right")
        case "Читает файлы":
            return (detail, "Чтение", "doc.text")
        case "Выполняет команду":
            return (detail, "Команда", "terminal")
        case "Ищет по коду":
            return (detail, "Поиск", "magnifyingglass")
        case "Пишет ответ":
            return (detail, "Ответ", "text.bubble.fill")
        default:
            if detail.hasPrefix("Выполняет") {
                return (detail, "Действие", "bolt.fill")
            }
            return (detail, "Думает", "brain.head.profile")
        }
    }

    /// Прогоняет демо-последовательность статусов локально, без подключения к dsh web —
    /// чтобы можно было проверить, как выглядит Live Activity, когда телефон не в той же сети.
    func simulateDemo() {
        handle(.running(detail: nil))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.handle(.running(detail: "Пишет код"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.handle(.waitingApproval("Нужно подтверждение: Edit"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { [weak self] in
            self?.handle(.idle)
        }
    }

    private func apply(statusText: String, shortLabel: String, iconName: String, isWaiting: Bool, isActive: Bool) {
        let content = DshActivityAttributes.ContentState(
            statusText: statusText,
            shortLabel: shortLabel,
            iconName: iconName,
            isWaiting: isWaiting,
            isActive: isActive,
            startedAt: runningStartedAt ?? .now
        )
        if let activity {
            Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
        } else {
            let attrs = DshActivityAttributes(title: "dsh")
            activity = try? Activity.request(attributes: attrs, content: ActivityContent(state: content, staleDate: nil))
        }
    }

    private func scheduleEnd(after seconds: TimeInterval) {
        endWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.endActivity() }
        endWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func endActivity() {
        endWorkItem?.cancel()
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
