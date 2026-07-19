import SwiftUI

/// Numbered Thermomix steps: the instruction plus capsule badges for the
/// machine settings (time / temperature / speed / reverse blade).
/// Renders one row per step (List/Form-friendly), like `StepsList`; `big`
/// enlarges everything for the hands-busy execution mode.
struct TmxStepsList: View {
    struct Item {
        let text: String
        let time: String?
        let temperature: String?
        let speed: String?
        let reverse: Bool

        var hasSettings: Bool { time != nil || temperature != nil || speed != nil || reverse }
    }

    let items: [Item]
    var big: Bool = false
    /// Step indices changed vs the previous version — flagged with a leading
    /// orange dot. Empty (the default) renders exactly like the plain recipe sheet.
    var modified: Set<Int> = []

    var body: some View {
        if big {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    row(index: index, item: item)
                }
            }
        } else {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                row(index: index, item: item)
            }
        }
    }

    private func row(index: Int, item: Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if !modified.isEmpty {
                Circle()
                    .fill(modified.contains(index) ? Theme.Status.changed : .clear)
                    .frame(width: 7, height: 7)
            }
            Text("\(index + 1)")
                .font((big ? Font.title2 : .subheadline).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: big ? 28 : 20, alignment: .trailing)
            VStack(alignment: .leading, spacing: big ? 10 : 6) {
                Text(item.text)
                    .font(big ? .title3 : .body)
                if item.hasSettings {
                    badges(item)
                }
            }
        }
    }

    private func badges(_ item: Item) -> some View {
        TmxSettingBadges(
            time: item.time,
            temperature: item.temperature,
            speed: item.speed,
            reverse: item.reverse,
            big: big
        )
    }
}

/// Read-only capsule badges for one step's Thermomix settings (time / temperature
/// / speed / reverse), tinted `Theme.Status.tmx`. Shared by the read-only
/// `TmxStepsList` and the editable import preview (where step text is editable
/// but the machine settings stay read-only).
struct TmxSettingBadges: View {
    let time: String?
    let temperature: String?
    let speed: String?
    let reverse: Bool
    var big: Bool = false

    var hasSettings: Bool { time != nil || temperature != nil || speed != nil || reverse }

    var body: some View {
        FlowLayout(spacing: 6) {
            if let time {
                badge(time, icon: "hourglass")
            }
            if let temperature {
                badge(temperature, icon: "thermometer.medium")
            }
            if reverse {
                badge("Inverse", icon: "arrow.trianglehead.counterclockwise")
            }
            if let speed {
                badge(speed, icon: "gauge.with.needle")
            }
        }
    }

    // Not a Label: Label's lazily-resolved style breaks inside a custom Layout
    // (the title vanishes and the icon stretches its capsule).
    private func badge(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font((big ? Font.subheadline : .caption).weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(Theme.Status.tmx)
        .padding(.horizontal, big ? 10 : 8)
        .padding(.vertical, big ? 5 : 3)
        .background(Theme.Status.tmx.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

extension TmxStepsList.Item {
    /// Builds the rows only when the settings usably mirror the steps: same
    /// count and at least one step actually carrying a setting. Returns `[]`
    /// otherwise — callers fall back to the plain `StepsList`.
    static func zipped(steps: [String], tmxSteps: [TmxSettings]) -> [TmxStepsList.Item] {
        guard tmxSteps.count == steps.count,
              tmxSteps.contains(where: { !$0.isEmpty }) else { return [] }
        return zip(steps, tmxSteps).map { text, settings in
            TmxStepsList.Item(
                text: text,
                time: settings.time,
                temperature: settings.temperature,
                speed: settings.speed,
                reverse: settings.reverse
            )
        }
    }
}

#Preview {
    List {
        TmxStepsList(items: [
            .init(
                text: "Mettre l'oignon et l'ail dans le bol, mixer.",
                time: "5 s", temperature: nil, speed: "5", reverse: false
            ),
            .init(
                text: "Ajouter l'huile d'olive, faire revenir.",
                time: "3 min", temperature: "120°C", speed: "1", reverse: false
            ),
            .init(
                text: "Ajouter le riz et le bouillon, cuire sans le gobelet doseur.",
                time: "14 min", temperature: "100°C", speed: "1", reverse: true
            ),
            .init(
                text: "Cuire les légumes à la vapeur dans le Varoma.",
                time: "20 min", temperature: "Varoma", speed: "2", reverse: false
            ),
            .init(
                text: "Servir aussitôt, parmesan à part.",
                time: nil, temperature: nil, speed: nil, reverse: false
            ),
        ])
    }
}
