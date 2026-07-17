import Foundation

@MainActor @Observable
final class RecipeViewModel {
    let recipeId: String
    var recipe: Recipe?
    var isLoading = false
    var error: String?

    init(recipeId: String) {
        self.recipeId = recipeId
    }

    /// Seeds the model with a fixture recipe for previews and the debug gallery,
    /// so `RecipeDetailView` renders fully offline (its `.task` skips loading
    /// because `recipe` is already set).
    init(previewRecipe: Recipe) {
        self.recipeId = previewRecipe.id
        self.recipe = previewRecipe
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            recipe = try await RecipeAPI.getRecipe(id: recipeId)
        } catch {
            self.error = reportError(error)
        }
        isLoading = false
    }
}
