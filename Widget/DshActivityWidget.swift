import ActivityKit
import SwiftUI
import WidgetKit

/// Экран блокировки + Dynamic Island для статуса dsh. Сама Activity создаётся/обновляется
/// из основного приложения (LiveActivityManager.swift) — этот таргет только рисует её.
struct DshActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DshActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.iconName)
                        .foregroundStyle(context.state.isWaiting ? .orange : .green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // .center у развёрнутого острова перекрывается датчиком/камерой —
                    // поэтому секундомер живёт справа, в .trailing, а не по центру.
                    if context.state.isActive {
                        Text(timerInterval: context.state.startedAt...farFuture, countsDown: false)
                            .monospacedDigit()
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text(context.attributes.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.statusText)
                        .font(.body)
                }
            } compactLeading: {
                Image(systemName: context.state.iconName)
                    .foregroundStyle(context.state.isWaiting ? .orange : .green)
            } compactTrailing: {
                // Свёрнутый остров: пока работает — секундомер, иначе короткая подпись
                // статуса вместо постоянной надписи "dsh".
                if context.state.isActive {
                    Text(timerInterval: context.state.startedAt...farFuture, countsDown: false)
                        .monospacedDigit()
                        .font(.caption2)
                        .frame(width: 44)
                } else {
                    Text(context.state.shortLabel)
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: context.state.iconName)
                    .foregroundStyle(context.state.isWaiting ? .orange : .green)
            }
        }
    }
}

/// Верхняя граница диапазона для Text(timerInterval:) — секундомер просто считает
/// от startedAt, конкретное "до" значения не играет роли, лишь бы было в будущем.
private let farFuture = Date(timeIntervalSinceNow: 60 * 60 * 24)

private struct LockScreenView: View {
    let context: ActivityViewContext<DshActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.iconName)
                .font(.title2)
                .foregroundStyle(context.state.isWaiting ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.state.statusText)
                    .font(.body)
                    .foregroundStyle(.white)
            }
            Spacer()
            if context.state.isActive {
                Text(timerInterval: context.state.startedAt...farFuture, countsDown: false)
                    .monospacedDigit()
                    .font(.body)
                    .foregroundStyle(.green)
            }
        }
        .padding()
    }
}
