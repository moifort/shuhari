import SwiftUI

/// The recipe's shopping list, inline in the fiche: name + quantity rows through
/// a small dedicated grid. Renders nothing when there are no ingredients (never
/// an empty section). Composes as a `Section` directly inside a `List`.
struct IngredientsSection: View {
    let ingredients: [Ingredient]

    var body: some View {
        if !ingredients.isEmpty {
            Section {
                IngredientsGrid(items: ingredients.map { ($0.name, $0.quantity) })
            } header: {
                // Trim the header's built-in top padding so the fiche stays compact.
                Text("Ingrédients")
                    .padding(.top, -14)
            }
        }
    }
}

/// A compact name/quantity grid: native `LabeledContent` rows (List/Form-friendly),
/// the quantity monospaced and trailing. Primitive-first — takes `(name, quantity)`
/// pairs, no domain struct.
struct IngredientsGrid: View {
    let items: [(name: String, quantity: String)]

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            LabeledContent(item.name) {
                Text(item.quantity)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    List {
        IngredientsSection(ingredients: Fixtures.bourguignonV3.ingredients)
        IngredientsSection(ingredients: Fixtures.risottoV2.ingredients)
    }
}
