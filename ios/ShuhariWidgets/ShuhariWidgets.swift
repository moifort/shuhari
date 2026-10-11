import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ShuhariWidgets: WidgetBundle {
    var body: some Widget {
        OvenLiveActivity()
    }
}

/// The oven's cooking on the lock screen and in the Dynamic Island. Draws only:
/// the app starts, updates and ends the activity (`OvenActivityController`).
struct OvenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OvenActivityAttributes.self) { context in
            OvenActivityView(
                title: context.attributes.title,
                subtitle: context.state.subtitle,
                programIcon: context.state.programIcon,
                startedAt: context.state.startedAt,
                endsAt: context.state.endsAt,
                isOver: isOver(context)
            )
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.programIcon)
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context)
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                timer(context)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func timer(_ context: ActivityViewContext<OvenActivityAttributes>) -> some View {
        OvenActivityTimer(
            startedAt: context.state.startedAt,
            endsAt: context.state.endsAt,
            isOver: isOver(context)
        )
    }

    /// Over when the oven said so, or when the timer ran out and nobody has spoken
    /// since — the activity goes stale at its end date, which redraws it here.
    private func isOver(_ context: ActivityViewContext<OvenActivityAttributes>) -> Bool {
        context.state.finished || (context.isStale && context.state.endsAt != nil)
    }
}

#Preview(
    "Écran verrouillé",
    as: .content,
    using: OvenActivityAttributes(title: "Pain de campagne")
) {
    OvenLiveActivity()
} contentStates: {
    OvenActivityAttributes.ContentState(
        program: "conventional", temperature: 230,
        startedAt: .now.addingTimeInterval(-600), endsAt: .now.addingTimeInterval(1800),
        finished: false
    )
    OvenActivityAttributes.ContentState(
        program: "conventional", temperature: 230,
        startedAt: .now.addingTimeInterval(-2400), endsAt: .now, finished: true
    )
}
