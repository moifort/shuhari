import SwiftUI

/// The library, grouped into the four type sections (café / cocktail / plat / tmx).
/// Each row is a NavigationLink into the recipe fiche. Composes as `Section`s
/// directly inside a `List`.
struct LibrarySection: View {
    let data: HomeData

    var body: some View {
        ForEach(RecipeType.allCases) { type in
            let recipes = data.recipes(of: type)
            if !recipes.isEmpty {
                Section {
                    ForEach(recipes) { recipe in
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
                        .accessibilityIdentifier("recipe-row-\(recipe.id)")
                    }
                } header: {
                    Text("\(type.label) (\(recipes.count))")
                }
            }
        }
    }
}
