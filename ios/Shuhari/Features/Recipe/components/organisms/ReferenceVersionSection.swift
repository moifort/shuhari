import SwiftUI

/// The recipe sheet's reference version — the best-rated one: its mise en place,
/// then its steps (with their per-step machine settings when present). The
/// ingredients are shown inline above by `IngredientsSection`, a coffee's dials by
/// `CoffeeParametersSection`. Composes as `Section`s directly inside a `List`.
struct ReferenceVersionSection: View {
    let version: RecipeVersion
    /// Step indices changed vs the previous version — flagged with an orange dot.
    /// Empty (the default) renders exactly like the plain recipe sheet.
    var modified: Set<Int> = []

    var body: some View {
        // Read whole before the first step. Absent on a version the AI has not
        // iterated on since the section existed: no empty section promising one.
        if !version.miseEnPlace.isEmpty {
            Section("Mise en place") {
                MiseEnPlaceList(lines: version.miseEnPlace)
            }
        }
        // Nothing to read, nothing to render: a coffee has no method by construction,
        // and an import that produced no step shows no empty section — it is written
        // from the edit sheet.
        if !version.steps.isEmpty {
            Section("Étapes") {
                switch version.content {
                case .dish(_, _, let steps, _):
                    StepsList(steps: steps, modified: modified)
                case .thermomix(_, _, let steps, _):
                    ThermomixStepsList(steps: steps, modified: modified)
                // A coffee has no steps at all — its dials say everything.
                case .coffee:
                    EmptyView()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    List {
        ReferenceVersionSection(version: Fixtures.bourguignonV3)
        ReferenceVersionSection(version: Fixtures.risottoV2)
    }
}
#endif
