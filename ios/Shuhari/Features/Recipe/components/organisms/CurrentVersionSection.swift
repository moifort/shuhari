import SwiftUI

/// The current reference version: params grid + steps + an execute button.
struct CurrentVersionSection: View {
    let version: RecipeVersion
    let onExecute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionHeader(title: "Version courante")
                Label("v\(version.number)", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                if let average = version.averageNote {
                    Text(String(format: "%.1f/10", average).replacingOccurrences(of: ".", with: ","))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ParamsGrid(items: version.params.map {
                    ParamsGrid.Item(key: $0.key, value: $0.value, highlighted: version.changedKeys.contains($0.key))
                })
                if !version.steps.isEmpty {
                    Divider()
                    StepsList(steps: version.steps)
                }
                Button(action: onExecute) {
                    Text("Exécuter la v\(version.number)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("execute-current-button")
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .carnetCard()
        }
    }
}
