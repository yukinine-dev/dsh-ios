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

    func handle(_ state: DshState) {
        defer { previous = state }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        switch state {
        case .disconnected:
            endActivity()

        case .idle:
            update(statusText: "🟢 Свободен", isWaiting: false)
            if case .running = previous {
                NotificationManager.fire(title: "dsh", body: "Готово")
            }
            scheduleEnd(after: 15)

        case .running(let detail):
            endWorkItem?.cancel()
            update(statusText: detail.map { "🧠 \($0)…" } ?? "🧠 Думает…", isWaiting: false)

        case .waitingApproval(let text):
            endWorkItem?.cancel()
            update(statusText: text, isWaiting: true)
            if previous != state {
                NotificationManager.fire(title: "dsh — нужно подтверждение", body: text)
            }
        }
    }

    private func update(statusText: String, isWaiting: Bool) {
        let content = DshActivityAttributes.ContentState(statusText: statusText, isWaiting: isWaiting)
        if let activity {
            Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
        } else {
            let attrs = DshActivityAttributes(title: "dsh")
            activity = try? Activity.request(attributes: attrs, content: ActivityContent(state: content, staleDate: nil))
        }
    }

    /// Прогоняет демо-последовательность статусов локально, без подключения к dsh web —
    /// чтобы можно было проверить, как выглядит Live Activity, когда телефон не в той же сети.
    func simulateDemo() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endWorkItem?.cancel()
        update(statusText: "🧠 Думает…", isWaiting: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.update(statusText: "🧠 Пишет код…", isWaiting: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.update(statusText: "Нужно подтверждение: Edit", isWaiting: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { [weak self] in
            self?.update(statusText: "🟢 Свободен", isWaiting: false)
            self?.scheduleEnd(after: 15)
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
