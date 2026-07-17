import SwiftUI

/// The "Activité récente" section: the most recent essais across all recipes.
/// Composes as a `Section` directly inside a `List`.
struct RecentTrialsSection: View {
    let essais: [RecentEssai]
    let titleProvider: (String) -> String

    var body: some View {
        if !essais.isEmpty {
            Section("Activité récente") {
                ForEach(essais) { essai in
                    NavigationLink(value: RecipeRoute.essai(recipeId: essai.recipeId, versionNumber: essai.versionNumber)) {
                        TrialRow(
                            recipeTitle: titleProvider(essai.recipeId),
                            versionNumber: essai.versionNumber,
                            note: essai.note,
                            remarks: essai.remarks,
                            date: essai.executedAt
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
            RecentTrialsSection(essais: Fixtures.homeData.recentEssais, titleProvider: { _ in Fixtures.bourguignon.title })
        }
    }
}
