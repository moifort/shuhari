import SwiftUI

/// The "Activité récente" section: the three most recent trials across all recipes.
/// Composes as a `Section` directly inside a `List`.
struct RecentTrialsSection: View {
    let trials: [Trial]
    let titleProvider: (String) -> String

    var body: some View {
        if !trials.isEmpty {
            Section("Activité récente") {
                ForEach(trials) { trial in
                    NavigationLink(value: RecipeRoute.trial(id: trial.id)) {
                        TrialRow(
                            recipeTitle: titleProvider(trial.recipeId),
                            versionNumber: trial.versionNumber,
                            note: trial.note,
                            remarks: trial.remarks,
                            date: trial.executedAt
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        RecentTrialsSection(
            trials: [
                Trial(id: "t1", recipeId: "1", versionNumber: 3, note: 8, remarks: "Équilibré, chocolat noir.", realParams: [], photoUrl: nil, executedAt: Date()),
                Trial(id: "t2", recipeId: "1", versionNumber: 2, note: 5, remarks: "Trop amer.", realParams: [], photoUrl: nil, executedAt: Date()),
            ],
            titleProvider: { _ in "Espresso — Brésil" }
        )
    }
}
