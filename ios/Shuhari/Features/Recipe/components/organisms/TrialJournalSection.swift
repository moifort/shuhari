import SwiftUI

/// The recipe's trial journal, most recent first. Each row pushes the trial detail.
struct TrialJournalSection: View {
    let recipeTitle: String
    let trials: [Trial]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Journal d’essais", count: trials.isEmpty ? nil : trials.count)
            if trials.isEmpty {
                Text("Aucun essai — exécute la recette pour démarrer la boucle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .carnetCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trials.enumerated()), id: \.element.id) { index, trial in
                        NavigationLink(value: RecipeRoute.trial(id: trial.id)) {
                            TrialRow(
                                recipeTitle: nil,
                                versionNumber: trial.versionNumber,
                                note: trial.note,
                                remarks: trial.remarks,
                                date: trial.executedAt
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("trial-row-\(trial.id)")
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
