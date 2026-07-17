import SwiftUI

/// Coordinator for an essai's detail. Loads the recipe and resolves the version
/// that carries the essai outcome.
struct TrialDetailView: View {
    let recipeId: String
    let versionNumber: Int

    @State private var recipe: Recipe?
    @State private var error: String?

    var body: some View {
        Group {
            if let recipe {
                if let version = recipe.version(versionNumber) {
                    TrialDetailPage(recipeTitle: recipe.title, version: version)
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

    private func load() async {
        do {
            recipe = try await RecipeAPI.getRecipe(id: recipeId)
        } catch {
            self.error = reportError(error)
        }
    }
}
