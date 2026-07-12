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
    NavigationStack {
        List {
            RecentTrialsSection(trials: Fixtures.espressoTrials, titleProvider: { _ in Fixtures.espresso.title })
        }
    }
}
