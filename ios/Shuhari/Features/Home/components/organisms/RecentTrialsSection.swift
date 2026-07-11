import SwiftUI

/// The "Activité récente" section: the three most recent trials across all recipes.
struct RecentTrialsSection: View {
    let trials: [Trial]
    let titleProvider: (String) -> String

    var body: some View {
        if !trials.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Activité récente")
                VStack(spacing: 0) {
                    ForEach(Array(trials.enumerated()), id: \.element.id) { index, trial in
                        NavigationLink(value: RecipeRoute.trial(id: trial.id)) {
                            TrialRow(
                                recipeTitle: titleProvider(trial.recipeId),
                                versionNumber: trial.versionNumber,
                                note: trial.note,
                                remarks: trial.remarks,
                                date: trial.executedAt
                            )
                        }
                        .buttonStyle(.plain)
                        if index < trials.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .carnetCard()
            }
        }
    }
}
