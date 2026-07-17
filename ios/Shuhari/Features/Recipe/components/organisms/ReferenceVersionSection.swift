import SwiftUI

/// The fiche's reference version — "la mieux notée": its steps (with per-step
/// Thermomix settings when present). The ingredients are shown inline above by
/// `IngredientsSection`. Composes as a `Section` directly inside a `List`.
struct ReferenceVersionSection: View {
    let version: RecipeVersion

    var body: some View {
        if !version.steps.isEmpty {
            Section {
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
}

#Preview {
    List {
        ReferenceVersionSection(version: Fixtures.bourguignonV3)
        ReferenceVersionSection(version: Fixtures.risottoV2)
    }
}
