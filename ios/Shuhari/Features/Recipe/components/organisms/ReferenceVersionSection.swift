import SwiftUI

/// The fiche's reference version — "la mieux notée": its steps (with per-step
/// Thermomix settings when present). The ingredients are shown inline above by
/// `IngredientsSection`. Composes as a `Section` directly inside a `List`.
struct ReferenceVersionSection: View {
    let version: RecipeVersion
    /// Step indices changed vs the previous version — flagged with an orange dot.
    /// Empty (the default) renders exactly like the plain fiche.
    var modified: Set<Int> = []

    var body: some View {
        if !version.steps.isEmpty {
            Section {
                let tmxItems = TmxStepsList.Item.zipped(steps: version.steps, tmxSteps: version.tmxSteps)
                if !tmxItems.isEmpty {
                    TmxStepsList(items: tmxItems, modified: modified)
                } else {
                    StepsList(steps: version.steps, modified: modified)
                }
            } header: {
                Text("Description")
            }
        }
    }
}

#Preview {
    List {
        ReferenceVersionSection(version: Fixtures.bourguignonV3)
        ReferenceVersionSection(version: Fixtures.risottoV2)
    }
}
