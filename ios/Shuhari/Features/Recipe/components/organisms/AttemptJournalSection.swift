import SwiftUI

/// The recipe's attempt journal, most recent first. Each row pushes the attempt detail.
/// Composes as a `Section` directly inside a `List`.
struct AttemptJournalSection: View {
    let recipeTitle: String
    let attempts: [RecipeVersion]

    var body: some View {
        Section {
            if attempts.isEmpty {
                Text("Aucun essai — note un essai pour démarrer la boucle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attempts) { version in
                    NavigationLink(value: RecipeRoute.attempt(recipeId: version.recipeId, versionNumber: version.number)) {
                        AttemptRow(
                            recipeTitle: nil,
                            versionNumber: version.number,
                            rating: version.rating ?? 0,
                            remarks: version.remarks ?? "",
                            date: version.executedAt ?? version.createdAt
                        )
                    }
                    .accessibilityIdentifier("attempt-row-v\(version.number)")
                }
            }
        } header: {
            Text(attempts.isEmpty ? "Journal d’essais" : "Journal d’essais (\(attempts.count))")
        }
    }
}

#Preview {
    List {
        AttemptJournalSection(recipeTitle: Fixtures.bourguignon.title, attempts: Fixtures.bourguignon.attempts)
        AttemptJournalSection(recipeTitle: "Negroni", attempts: [])
    }
}
