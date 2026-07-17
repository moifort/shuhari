import SwiftUI

/// The recipe's essai journal, most recent first. Each row pushes the essai detail.
/// Composes as a `Section` directly inside a `List`.
struct TrialJournalSection: View {
    let recipeTitle: String
    let essais: [RecipeVersion]

    var body: some View {
        Section {
            if essais.isEmpty {
                Text("Aucun essai — note un essai pour démarrer la boucle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(essais) { version in
                    NavigationLink(value: RecipeRoute.essai(recipeId: version.recipeId, versionNumber: version.number)) {
                        TrialRow(
                            recipeTitle: nil,
                            versionNumber: version.number,
                            note: version.note ?? 0,
                            remarks: version.remarks ?? "",
                            date: version.executedAt ?? version.createdAt
                        )
                    }
                    .accessibilityIdentifier("trial-row-v\(version.number)")
                }
            }
        } header: {
            Text(essais.isEmpty ? "Journal d’essais" : "Journal d’essais (\(essais.count))")
        }
    }
}

#Preview {
    List {
        TrialJournalSection(recipeTitle: Fixtures.bourguignon.title, essais: Fixtures.bourguignon.essais)
        TrialJournalSection(recipeTitle: "Negroni", essais: [])
    }
}
