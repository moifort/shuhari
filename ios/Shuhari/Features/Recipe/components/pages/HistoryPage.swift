import SwiftUI

/// The version history: a vertical timeline, newest at the top, plus any linked
/// variations issued from this recipe.
struct HistoryPage: View {
    let recipe: Recipe

    private var orderedVersions: [RecipeVersion] {
        recipe.versions.sorted { $0.number > $1.number }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historique")
                        .font(.system(.title, design: .serif).weight(.bold))
                    Text("\(recipe.title) — chaque cran ne change que ce qui est écrit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(orderedVersions.enumerated()), id: \.element.number) { index, version in
                        VersionTimelineItem(
                            number: version.number,
                            change: version.change,
                            originDetail: version.originDetail,
                            averageNote: version.averageNote,
                            trialCount: version.trialCount,
                            date: version.createdAt,
                            isCurrent: version.number == recipe.currentVersion?.number,
                            isToTest: version.number == recipe.toTest?.number,
                            isLast: index == orderedVersions.count - 1
                        )
                    }
                }

                VariationsSection(variations: recipe.variations)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.inline)
    }
}
