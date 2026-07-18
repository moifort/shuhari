import SwiftUI

/// Coordinator for a version's detail. Loads the recipe, resolves the version and
/// its predecessor (for the diff), and maps them to the page's primitives.
struct EssaiDetailView: View {
    let recipeId: String
    let versionNumber: Int

    @State private var recipe: Recipe?
    @State private var error: String?

    var body: some View {
        Group {
            if let recipe {
                if let version = recipe.version(versionNumber) {
                    // The previous version is the diff base (nil for v1 → no highlight).
                    let previous = recipe.version(version.number - 1)
                    EssaiDetailPage(
                        recipeTitle: recipe.title,
                        versionNumber: version.number,
                        date: version.executedAt ?? version.createdAt,
                        change: version.change,
                        why: version.why,
                        ingredients: ingredientItems(version, previous: previous),
                        steps: stepItems(version, previous: previous),
                        hasResult: hasResult(version),
                        note: version.note,
                        remarks: version.remarks,
                        photoUrl: version.photoUrl
                    )
                } else {
                    ContentUnavailableView("Essai introuvable", systemImage: "questionmark.circle")
                }
            } else if let error {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
            }
        }
        .task { if recipe == nil { await load() } }
    }

    /// Whether the version carries an essai outcome worth showing.
    private func hasResult(_ version: RecipeVersion) -> Bool {
        version.tried || version.note != nil || version.remarks?.isEmpty == false || version.photoUrl != nil
    }

    /// An ingredient is highlighted when the previous version has no ingredient
    /// with the exact same name and quantity (new or modified). No previous
    /// version (v1) means nothing is highlighted.
    private func ingredientItems(_ version: RecipeVersion, previous: RecipeVersion?) -> [EssaiDetailPage.IngredientItem] {
        version.ingredients.map { ingredient in
            let highlighted = previous.map {
                !$0.ingredients.contains { $0.name == ingredient.name && $0.quantity == ingredient.quantity }
            } ?? false
            return EssaiDetailPage.IngredientItem(name: ingredient.name, quantity: ingredient.quantity, highlighted: highlighted)
        }
    }

    /// A step is highlighted when its exact text is absent from the previous
    /// version's steps. Per-step Thermomix settings ride along, aligned by index.
    private func stepItems(_ version: RecipeVersion, previous: RecipeVersion?) -> [EssaiDetailPage.StepItem] {
        version.steps.enumerated().map { index, text in
            let tmx = index < version.tmxSteps.count ? version.tmxSteps[index] : nil
            let highlighted = previous.map { !$0.steps.contains(text) } ?? false
            return EssaiDetailPage.StepItem(
                index: index,
                text: text,
                time: tmx?.time,
                temperature: tmx?.temperature,
                speed: tmx?.speed,
                reverse: tmx?.reverse ?? false,
                highlighted: highlighted
            )
        }
    }

    private func load() async {
        do {
            recipe = try await RecipeAPI.getRecipe(id: recipeId)
        } catch {
            self.error = reportError(error)
        }
    }
}
