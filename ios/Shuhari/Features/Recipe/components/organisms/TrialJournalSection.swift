import SwiftUI

/// The recipe's trial journal, most recent first. Each row pushes the trial detail.
/// Composes as a `Section` directly inside a `List`.
struct TrialJournalSection: View {
    let recipeTitle: String
    let trials: [Trial]

    var body: some View {
        Section {
            if trials.isEmpty {
                Text("Aucun essai — note un essai pour démarrer la boucle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(trials) { trial in
                    NavigationLink(value: RecipeRoute.trial(id: trial.id)) {
                        TrialRow(
                            recipeTitle: nil,
                            versionNumber: trial.versionNumber,
                            note: trial.note,
                            remarks: trial.remarks,
                            date: trial.executedAt
                        )
                    }
                    .accessibilityIdentifier("trial-row-\(trial.id)")
                }
            }
        } header: {
            Text(trials.isEmpty ? "Journal d’essais" : "Journal d’essais (\(trials.count))")
        }
    }
}

#Preview {
    List {
        TrialJournalSection(recipeTitle: Fixtures.bourguignon.title, trials: Fixtures.bourguignonTrials)
        TrialJournalSection(recipeTitle: "Negroni", trials: [])
    }
}
