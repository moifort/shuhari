import SwiftUI

/// The recipe's shopping list, presented as a non-modal bottom panel: it stays up
/// (detent `.medium`) while the recipe steps remain scrollable behind it, and drags
/// away to dismiss. Ingredients render through the shared `ParamsGrid`.
struct IngredientsSheet: View {
    let ingredients: [Ingredient]

    var body: some View {
        List {
            Section("Ingrédients") {
                ParamsGrid(items: ingredients.map {
                    ParamsGrid.Item(key: $0.name, value: $0.quantity, highlighted: false)
                })
            }
        }
        .accessibilityIdentifier("ingredients-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}

#Preview {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            IngredientsSheet(ingredients: Fixtures.espressoV3.ingredients)
        }
}
