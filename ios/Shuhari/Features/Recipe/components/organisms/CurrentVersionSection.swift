import SwiftUI

/// The current reference version: params rows + steps. Ingredients live in the
/// slide-up `IngredientsSheet` and the execute action in the bottom bar, both
/// owned by `RecipeDetailView`. Composes as a `Section` directly inside a `List`.
struct CurrentVersionSection: View {
    let version: RecipeVersion

    var body: some View {
        Section {
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
        CurrentVersionSection(version: Fixtures.espressoV3)
        CurrentVersionSection(version: Fixtures.risottoV2)
    }
}
