import SwiftUI

/// The paginated library, always cut into sections along the axis it is sorted on:
/// the month of the last update ("Juillet 2026") or the dish course ("Entrée",
/// "Plat", …), the server ordering the rows within a section either way. Each row
/// navigates into the recipe sheet and prefetches the next page as it appears; a
/// `LoadMoreRow` sentinel closes the list while more pages remain. Composes as
/// `Section`s / rows directly inside a `List`.
struct LibrarySection: View {
    let recipes: [LibraryRecipe]
    /// The section axis: `.month` for the "Dernière modification" sort, `.course`
    /// for the "Type de plat" sort.
    let grouping: LibraryGrouping
    var hasMore: Bool = false
    var loadMoreFailed: Bool = false
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    var body: some View {
        switch grouping {
        case .month:
            ForEach(LibraryMonthGroup.grouping(recipes)) { group in
                section(group.label, group.recipes)
            }
        case .course:
            ForEach(LibraryCourseGroup.grouping(recipes)) { group in
                section(group.label, group.recipes)
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

    private func section(_ label: String, _ recipes: [LibraryRecipe]) -> some View {
        Section {
            ForEach(recipes) { recipe in
                row(recipe)
            }
        } header: {
            Text(label)
        }
    }

    @ViewBuilder
    private func row(_ recipe: LibraryRecipe) -> some View {
        ZStack {
            // A zero-opacity link keeps the row tappable without the List's chevron.
            NavigationLink(value: RecipeRoute.recipe(id: recipe.id)) { EmptyView() }
                .opacity(0)
            LibraryRow(
                title: recipe.title,
                type: recipe.type,
                category: recipe.category,
                versionCount: recipe.versionCount,
                bestRating: recipe.bestRating,
                favorite: recipe.favorite
            )
        }
        .accessibilityIdentifier("recipe-row-\(recipe.id)")
        .onAppear { onPrefetch(recipe.id) }
    }
}

#Preview("Par mois") {
    NavigationStack {
        List {
            LibrarySection(recipes: Fixtures.libraryRecipes, grouping: .month, hasMore: true)
        }
    }
}

#Preview("Par type de plat") {
    NavigationStack {
        List {
            LibrarySection(recipes: Fixtures.libraryRecipes, grouping: .course)
        }
    }
}
