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
