import SwiftUI

/// The fiche's reference version — "la mieux notée": params rows + steps. The
/// ingredients are shown inline above by `IngredientsSection`. Composes as a
/// `Section` directly inside a `List`.
struct ReferenceVersionSection: View {
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
            // Trim the header's built-in top padding so the fiche stays compact.
            Text("Description")
                .padding(.top, -14)
        }
    }
}

#Preview {
    List {
        ReferenceVersionSection(version: Fixtures.espressoV3)
        ReferenceVersionSection(version: Fixtures.risottoV2)
    }
}
