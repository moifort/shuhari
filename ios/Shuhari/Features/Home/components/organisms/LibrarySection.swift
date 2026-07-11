import SwiftUI

/// The library, grouped into the four type sections (café / cocktail / plat / tmx).
/// Each row is a NavigationLink into the recipe fiche.
struct LibrarySection: View {
    let data: HomeData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Bibliothèque")
            ForEach(RecipeType.allCases) { type in
                let recipes = data.recipes(of: type)
                if !recipes.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        SectionHeader(title: type.label, count: recipes.count, tint: type.color)
                        VStack(spacing: 0) {
                            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                                NavigationLink(value: RecipeRoute.recipe(id: recipe.id)) {
                                    LibraryRow(
                                        title: recipe.title,
                                        type: recipe.type,
                                        currentVersionNumber: recipe.currentVersionNumber,
                                        averageNote: recipe.averageNote,
                                        toTestNumber: recipe.toTestNumber,
                                        isDerived: recipe.isDerived
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("recipe-row-\(recipe.id)")
                                if index < recipes.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .carnetCard()
                    }
                }
            }
        }
    }
}
