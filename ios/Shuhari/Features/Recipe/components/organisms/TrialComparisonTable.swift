import SwiftUI

/// "Cible vs réel" rows: version targets against the parameters actually used,
/// with the deviations highlighted. Composes as a `Section` inside a `List`.
struct TrialComparisonTable: View {
    let targets: [Param]
    /// Only the deviations (keyed by param name).
    let real: [Param]

    private func realValue(for key: String) -> (value: String, deviated: Bool) {
        if let match = real.first(where: { $0.key == key }) {
            return (match.value, true)
        }
        return (targets.first(where: { $0.key == key })?.value ?? "—", false)
    }

    var body: some View {
        Section("Cible vs réel") {
            ForEach(targets) { target in
                let real = realValue(for: target.key)
                LabeledContent(target.key) {
                    HStack(spacing: 6) {
                        if real.deviated {
                            Text(target.value)
                                .monospacedDigit()
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text(real.value)
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        } else {
                            Text(target.value)
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        TrialComparisonTable(
            targets: [
                Param(key: "Dose", value: "18,5 g"),
                Param(key: "Température", value: "92 °C"),
            ],
            real: [
                Param(key: "Température", value: "93 °C"),
            ]
        )
    }
}
