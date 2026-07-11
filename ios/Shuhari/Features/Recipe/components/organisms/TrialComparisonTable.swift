import SwiftUI

/// "Cible vs réel" table: version targets against the parameters actually used,
/// with the deviations highlighted.
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
        VStack(spacing: 0) {
            HStack {
                Text("Paramètre").frame(maxWidth: .infinity, alignment: .leading)
                Text("Cible").frame(width: 90, alignment: .leading)
                Text("Réel").frame(width: 90, alignment: .leading)
            }
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 6)
            Divider()
            ForEach(targets) { target in
                let real = realValue(for: target.key)
                HStack {
                    Text(target.key)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(target.value)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(width: 90, alignment: .leading)
                    Text(real.value)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(real.deviated ? Color.orange : .primary)
                        .frame(width: 90, alignment: .leading)
                }
                .padding(.vertical, 8)
                if target.id != targets.last?.id {
                    Divider()
                }
            }
        }
        .padding(15)
        .carnetCard()
    }
}
