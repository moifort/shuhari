import SwiftUI

/// The recipe's shopping list, inline in the recipe sheet: name + quantity rows through
/// a small dedicated grid. Renders nothing when there are no ingredients (never
/// an empty section). Composes as a `Section` directly inside a `List`.
struct IngredientsSection: View {
    let ingredients: [Ingredient]
    /// Names of ingredients changed vs the previous version — flagged with an
    /// orange dot. Empty (the default) renders exactly like the plain recipe sheet.
    var modified: Set<String> = []

    var body: some View {
        if !ingredients.isEmpty {
            Section {
                IngredientsGrid(items: ingredients.map { ($0.name, $0.quantity) }, modified: modified)
            } header: {
                // Trim the header's built-in top padding so the recipe sheet stays compact.
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
    /// Names to flag as changed. Empty (the default) keeps the exact plain-recipe-sheet
    /// `LabeledContent` layout — no leading dot, no shift.
    var modified: Set<String> = []

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            if modified.isEmpty {
                LabeledContent(item.name) {
                    Text(item.quantity)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            } else {
                HStack(spacing: 10) {
                    Circle()
                        .fill(modified.contains(item.name) ? Theme.Status.changed : .clear)
                        .frame(width: 7, height: 7)
                    Text(item.name)
                    Spacer(minLength: 8)
                    Text(item.quantity)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
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
