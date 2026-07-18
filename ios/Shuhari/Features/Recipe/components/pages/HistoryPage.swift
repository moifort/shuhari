import SwiftUI

/// The version history: newest at the top.
struct HistoryPage: View {
    let recipe: Recipe

    private var orderedVersions: [RecipeVersion] {
        recipe.versions.sorted { $0.number > $1.number }
    }

    var body: some View {
        List {
            Section {
                ForEach(orderedVersions, id: \.number) { version in
                    // Any version is cookable — tapping a row opens its fiche.
                    NavigationLink(value: RecipeRoute.essai(recipeId: recipe.id, versionNumber: version.number)) {
                        VersionTimelineItem(
                            number: version.number,
                            change: version.change,
                            originDetail: version.originDetail,
                            note: version.note,
                            tried: version.tried,
                            date: version.createdAt,
                            isFocus: version.number == recipe.versionToOpen.number,
                            isLast: version.number == orderedVersions.last?.number
                        )
                    }
                }
            } footer: {
                Text("Chaque cran ne change que ce qui est écrit.")
            }

            EssaiJournalSection(recipeTitle: recipe.title, essais: recipe.essais)
        }
        .navigationTitle("Historique")
        .navigationSubtitle(recipe.title)
    }
}

#Preview {
    NavigationStack {
        HistoryPage(recipe: Fixtures.bourguignon)
    }
}
