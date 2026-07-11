import SwiftUI

/// Coordinator for the version history screen.
struct HistoryView: View {
    let recipeId: String
    @State private var viewModel: RecipeViewModel

    init(recipeId: String) {
        self.recipeId = recipeId
        self._viewModel = State(initialValue: RecipeViewModel(recipeId: recipeId))
    }

    var body: some View {
        Group {
            if let recipe = viewModel.recipe {
                HistoryPage(recipe: recipe)
            } else if let error = viewModel.error {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
            }
        }
        .task { if viewModel.recipe == nil { await viewModel.load() } }
    }
}
