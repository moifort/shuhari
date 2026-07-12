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
            .buttonStyle(.borderless)
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

#Preview {
    List {
        CurrentVersionSection(
            version: RecipeVersion(
                number: 3,
                change: "Mouture plus fine",
                why: nil,
                originKind: .aiProposal,
                originDetail: nil,
                changedKeys: ["Mouture"],
                params: [
                    Param(key: "Dose", value: "18,5 g"),
                    Param(key: "Température", value: "92 °C"),
                    Param(key: "Mouture", value: "fine"),
                ],
                steps: ["Chauffer l'eau à 92 °C.", "Extraire 27 s."],
                averageNote: 7.5,
                trialCount: 2,
                createdAt: Date()
            ),
            onExecute: {}
        )
    }
}
