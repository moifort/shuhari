import SwiftUI

/// The current reference version: params rows + steps + an execute button.
/// Composes as a `Section` directly inside a `List`.
struct CurrentVersionSection: View {
    let version: RecipeVersion
    let onExecute: () -> Void

    var body: some View {
        Section {
            ParamsGrid(items: version.params.map {
                ParamsGrid.Item(key: $0.key, value: $0.value, highlighted: version.changedKeys.contains($0.key))
            })
            StepsList(steps: version.steps)
            Button(action: onExecute) {
                Label("Exécuter la v\(version.number)", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("execute-current-button")
        } header: {
            HStack(spacing: 8) {
                Text("Version courante")
                Label("v\(version.number)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .textCase(nil)
                if let average = version.averageNote {
                    Text(String(format: "%.1f/10", average).replacingOccurrences(of: ".", with: ","))
                        .foregroundStyle(.tertiary)
                        .textCase(nil)
                }
            }
        }
    }
}
