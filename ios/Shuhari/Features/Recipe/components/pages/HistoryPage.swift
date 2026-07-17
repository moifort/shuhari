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
                    VersionTimelineItem(
                        number: version.number,
                        change: version.change,
                        originDetail: version.originDetail,
                        averageNote: version.averageNote,
                        trialCount: version.trialCount,
                        date: version.createdAt,
                        isCurrent: version.number == recipe.currentVersion?.number,
                        isToTest: version.number == recipe.toTest?.number,
                        isLast: version.number == orderedVersions.last?.number
                    )
                }
            } footer: {
                Text("Chaque cran ne change que ce qui est écrit.")
            }

            TrialJournalSection(recipeTitle: recipe.title, trials: recipe.trials)
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
