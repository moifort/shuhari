import SwiftUI

/// The cooking as the lock screen shows it: what is in the oven, how, and how long
/// is left. Primitive-first, so the debug gallery and the previews draw it without
/// an `Activity` — the widget extension only maps its state onto these values.
///
/// Every timer here is a `Text(timerInterval:)` or `ProgressView(timerInterval:)`:
/// the system advances them itself, while neither the app nor the extension runs.
struct OvenActivityView: View {
    let title: String
    /// "Chaleur tournante · 180 °C" — the dials, written out.
    let subtitle: String
    let programIcon: String
    let startedAt: Date
    /// nil on a cooking without a timer, which then counts up from `startedAt`.
    let endsAt: Date?
    /// The oven said it is over, or the timer ran out with no word since.
    let isOver: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: programIcon)
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    // Two lines: a probe cooking says mode, heat AND core, which
                    // one line cuts off at the very value the probe is there for.
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                // A fixed width: a live timer text claims all the room it can,
                // which cut the recipe's name down to "Pain de campa…".
                OvenActivityTimer(startedAt: startedAt, endsAt: endsAt, isOver: isOver)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .frame(width: 96, alignment: .trailing)
            }
            if let endsAt, !isOver {
                ProgressView(timerInterval: Self.interval(startedAt, endsAt), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(.orange)
            }
        }
        .padding()
    }

    /// The range a timer runs over. A re-anchored end can land before the start the
    /// activity was opened with, and a reversed range is a crash, not an empty bar.
    static func interval(_ start: Date, _ end: Date) -> ClosedRange<Date> {
        min(start, end)...end
    }
}

/// The time on the cooking: down to the oven's timer, up from the start without
/// one, "Prêt" once it is over. Shared by the lock screen and the Dynamic Island.
struct OvenActivityTimer: View {
    let startedAt: Date
    let endsAt: Date?
    let isOver: Bool

    var body: some View {
        if isOver {
            Text("Prêt")
                .foregroundStyle(.orange)
        } else if let endsAt {
            Text(timerInterval: OvenActivityView.interval(startedAt, endsAt), countsDown: true)
                .multilineTextAlignment(.trailing)
        } else {
            Text(startedAt, style: .timer)
                .multilineTextAlignment(.trailing)
        }
    }
}

extension OvenActivityAttributes.ContentState {
    /// The dials in one line, the way the recipe sheet writes them.
    var subtitle: String {
        let mode = program.flatMap(OvenProgram.init(rawValue:))
        return [
            mode?.label(assisted: assisted),
            // A non-breaking space: "180" and "°C" never land on two lines.
            temperature.map { "\($0)\u{00A0}°C" },
            core.map { "à cœur \($0)\u{00A0}°C" },
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    var programIcon: String {
        program.flatMap(OvenProgram.init(rawValue:))?.iconName ?? "flame.fill"
    }
}

#Preview("Minuteur") {
    OvenActivityView(
        title: "Pain de campagne",
        subtitle: "Sole et voûte · 230 °C",
        programIcon: "thermometer.medium",
        startedAt: .now.addingTimeInterval(-600),
        endsAt: .now.addingTimeInterval(1800),
        isOver: false
    )
}

#Preview("Sonde") {
    OvenActivityView(
        title: "Rôti de porc",
        subtitle: "Chaleur tournante · 180 °C · à cœur 65 °C",
        programIcon: "fan",
        startedAt: .now.addingTimeInterval(-1500),
        endsAt: nil,
        isOver: false
    )
}

#Preview("Terminée") {
    OvenActivityView(
        title: "Pain de campagne",
        subtitle: "Sole et voûte · 230 °C",
        programIcon: "thermometer.medium",
        startedAt: .now.addingTimeInterval(-2400),
        endsAt: .now,
        isOver: true
    )
}
