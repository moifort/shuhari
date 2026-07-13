import SwiftUI

/// The current reference version: params rows + steps + an execute button.
/// Composes as a `Section` directly inside a `List`.
struct CurrentVersionSection: View {
    let version: RecipeVersion
    let onExecute: () -> Void

    var body: some View {
        Section {
            if !version.ingredients.isEmpty {
                ParamsGrid(items: version.ingredients.map {
                    ParamsGrid.Item(key: $0.name, value: $0.quantity, highlighted: false)
                })
            }
            if !version.params.isEmpty {
                ParamsGrid(items: version.params.map {
                    ParamsGrid.Item(key: $0.key, value: $0.value, highlighted: version.changedKeys.contains($0.key))
                })
            }
            if let tmxItems = TmxStepsList.Item.zipped(steps: version.steps, tmxSteps: version.tmxSteps) {
                TmxStepsList(items: tmxItems)
            } else {
                StepsList(steps: version.steps)
            }
            Button(action: onExecute) {
                Label("Exécuter la v\(version.number)", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("execute-current-button")
        } header: {
            HStack(spacing: 8) {
                Text("Version courante")
                Label("v\(version.number)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Status.current)
                    .textCase(nil)
                if let average = version.averageNote {
                    Text(NoteFormat.average(average))
                        .foregroundStyle(.tertiary)
                        .textCase(nil)
                }
            }
        }
    }
}

#Preview {
    List {
        CurrentVersionSection(version: Fixtures.espressoV3, onExecute: {})
        CurrentVersionSection(version: Fixtures.risottoV2, onExecute: {})
    }
}
