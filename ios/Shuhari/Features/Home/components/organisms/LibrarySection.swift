import SwiftUI

/// The paginated library. When sorted by last modification the rows are grouped by
/// month ("Juillet 2026"); when sorted by dish course the server already orders them
/// (Entrée → … → Boulangerie) so they render as a flat list. Each row is a
/// NavigationLink into the fiche and prefetches the next page as it appears; a
/// `LoadMoreRow` sentinel closes the list while more pages remain. Composes as
/// `Section`s / rows directly inside a `List`.
struct LibrarySection: View {
    let recipes: [LibraryRecipe]
    /// `true` for the "Dernière modification" sort (month sections); `false` for the
    /// "Type de plat" sort (flat, server-ordered).
    let grouped: Bool
    var hasMore: Bool = false
    var loadMoreFailed: Bool = false
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    var body: some View {
        if grouped {
            ForEach(LibraryMonthGroup.grouping(recipes)) { group in
                Section {
                    ForEach(group.recipes) { recipe in
                        row(recipe)
                    }
                } header: {
                    Text(group.label)
                }
            }
        } else {
            Section {
                ForEach(recipes) { recipe in
                    row(recipe)
                }
            }
        }

        if hasMore {
            LoadMoreRow(
                failed: loadMoreFailed,
                loadingLabel: "Chargement d’autres recettes",
                onLoadMore: onLoadMore
            )
        }
    }

    @ViewBuilder
    private func row(_ recipe: LibraryRecipe) -> some View {
        NavigationLink(value: RecipeRoute.recipe(id: recipe.id)) {
            LibraryRow(
                title: recipe.title,
                type: recipe.type,
                versionCount: recipe.versionCount,
                bestNote: recipe.bestNote,
                averageNote: recipe.averageNote
            )
        }
        .accessibilityIdentifier("recipe-row-\(recipe.id)")
        .onAppear { onPrefetch(recipe.id) }
    }
}

#Preview("Par mois") {
    NavigationStack {
        List {
            LibrarySection(recipes: Fixtures.homeData.library, grouped: true, hasMore: true)
        }
    }
}

#Preview("Par type de plat") {
    NavigationStack {
        List {
            LibrarySection(recipes: Fixtures.homeData.library, grouped: false)
        }
    }
}
