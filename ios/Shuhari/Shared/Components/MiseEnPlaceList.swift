import SwiftUI

/// What is readied before the first step, one row per preparation — a checklist
/// rather than a method, so the rows wear a tick mark instead of a number: they are
/// done in any order, and all of them before anything cooks. Renders one row per
/// line (List/Form-friendly), like `StepsList`.
struct MiseEnPlaceList: View {
    let lines: [String]

    var body: some View {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20)
                    .accessibilityHidden(true)
                Text(line)
                    .font(.body)
            }
        }
    }
}

#Preview {
    List {
        Section("Mise en place") {
            MiseEnPlaceList(lines: [
                "Sortir le bœuf 1 h avant.",
                "Émincer 2 oignons, tailler 3 carottes en rondelles.",
                "Préchauffer le four à 160 °C.",
            ])
        }
    }
}
