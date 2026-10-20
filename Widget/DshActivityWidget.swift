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
                    Image(systemName: context.state.isWaiting ? "exclamationmark.circle.fill" : "cpu")
                        .foregroundStyle(context.state.isWaiting ? .orange : .green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.statusText)
                        .font(.body)
                }
            } compactLeading: {
                Image(systemName: context.state.isWaiting ? "exclamationmark.circle.fill" : "cpu")
                    .foregroundStyle(context.state.isWaiting ? .orange : .green)
            } compactTrailing: {
                Text(context.attributes.title)
                    .font(.caption2)
            } minimal: {
                Image(systemName: context.state.isWaiting ? "exclamationmark.circle.fill" : "cpu")
                    .foregroundStyle(context.state.isWaiting ? .orange : .green)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<DshActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.state.isWaiting ? "exclamationmark.circle.fill" : "cpu")
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
        }
        .padding()
    }
}
