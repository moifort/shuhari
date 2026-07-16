import SwiftUI

/// The recipe's shopping list, inline in the fiche: name + quantity rows through
/// the shared `ParamsGrid`. Renders nothing when there are no ingredients (never
/// an empty section). Composes as a `Section` directly inside a `List`.
struct IngredientsSection: View {
    let ingredients: [Ingredient]

    var body: some View {
        if !ingredients.isEmpty {
            Section {
                ParamsGrid(items: ingredients.map {
                    ParamsGrid.Item(key: $0.name, value: $0.quantity, highlighted: false)
                })
            } header: {
                // Trim the header's built-in top padding so the fiche stays compact.
                Text("Ingrédients")
                    .padding(.top, -14)
            }
        }
    }
}

#Preview {
    List {
        IngredientsSection(ingredients: Fixtures.espressoV3.ingredients)
        IngredientsSection(ingredients: Fixtures.risottoV2.ingredients)
    }
}
