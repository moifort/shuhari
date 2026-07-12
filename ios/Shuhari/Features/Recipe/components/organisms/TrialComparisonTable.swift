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
                    if real.deviated {
                        DiffValue(from: target.value, to: real.value)
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

#Preview {
    List {
        TrialComparisonTable(
            targets: Fixtures.espressoV3.params,
            real: [Param(key: "Température", value: "94 °C")]
        )
    }
}
