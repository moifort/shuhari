import SwiftUI

/// Numbered Thermomix steps: the instruction plus capsule badges for the
/// machine settings (time / temperature / speed / reverse blade).
/// Renders one row per step (List/Form-friendly), like `StepsList`.
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

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            row(index: index, item: item)
        }
    }

    private func row(index: Int, item: Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                if item.hasSettings {
                    badges(item)
                }
            }
        }
    }

    private func badges(_ item: Item) -> some View {
        FlowLayout(spacing: 6) {
            if let time = item.time {
                badge(time, icon: "timer")
            }
            if let temperature = item.temperature {
                badge(temperature, icon: "thermometer.medium")
            }
            if let speed = item.speed {
                badge(speed, icon: "gauge.with.needle")
            }
            if item.reverse {
                badge("Inverse", icon: "arrow.trianglehead.counterclockwise")
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
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(Theme.Status.tmx)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.Status.tmx.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

extension TmxStepsList.Item {
    /// Builds the rows only when the settings usably mirror the steps: same
    /// count and at least one step actually carrying a setting. Returns nil
    /// otherwise — callers fall back to the plain `StepsList`.
    static func zipped(steps: [String], tmxSteps: [TmxSettings?]?) -> [TmxStepsList.Item]? {
        guard let tmxSteps, tmxSteps.count == steps.count,
              tmxSteps.contains(where: { $0?.isEmpty == false }) else { return nil }
        return zip(steps, tmxSteps).map { text, settings in
            TmxStepsList.Item(
                text: text,
                time: settings?.time,
                temperature: settings?.temperature,
                speed: settings?.speed,
                reverse: settings?.reverse ?? false
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
