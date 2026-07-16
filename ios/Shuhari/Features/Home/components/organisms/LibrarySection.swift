import SwiftUI

/// The library, grouped by the month of each recipe's last update ("Juillet
/// 2026"). Each row is a NavigationLink into the recipe fiche. Composes as
/// `Section`s directly inside a `List`.
struct LibrarySection: View {
    let data: HomeData

    var body: some View {
        ForEach(data.libraryByMonth()) { group in
            Section {
                ForEach(group.recipes) { recipe in
                    NavigationLink(value: RecipeRoute.recipe(id: recipe.id)) {
                        LibraryRow(
                            title: recipe.title,
                            type: recipe.type,
                            versionCount: recipe.versionCount,
                            bestNote: recipe.bestNote,
                            averageNote: recipe.averageNote,
                            isDerived: recipe.isDerived
                        )
                    }
                    .accessibilityIdentifier("recipe-row-\(recipe.id)")
                }
            } header: {
                Text(group.label)
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            LibrarySection(data: Fixtures.homeData)
        }
    }
}
