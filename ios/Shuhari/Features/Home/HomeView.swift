import SwiftUI

/// One category tab of the Carnet (Cuisine / Café / Cocktail). Owns the
/// NavigationStack, the settings sheet and the recipe flow (fiche → historique →
/// essai → proposition + execution cover). The home data is filtered to
/// `categoryTypes`.
struct HomeView: View {
    let title: String
    let categoryTypes: Set<RecipeType>
    @Binding var importedRecipe: ImportedRecipe?

    @State private var viewModel = HomeViewModel()
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var execution: ExecutionRequest?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let data = viewModel.data {
                    HomePage(
                        data: data.filtered(to: categoryTypes),
                        title: title,
                        onExecute: { item in
                            execution = ExecutionRequest(recipeId: item.id, versionNumber: item.versionNumber)
                        },
                        onSettings: { showSettings = true }
                    )
                } else if let error = viewModel.error {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView("Chargement…")
                }
            }
            .recipeFlow(path: $path, execution: $execution) {
                Task { await viewModel.load() }
            }
        }
        .task {
            if viewModel.data == nil { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .carnetDataDidReload)) { _ in
            Task { await viewModel.load() }
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    /// Push the freshly imported recipe's fiche — but only in the tab that owns
    /// its type. Handles both the already-mounted tab (`onChange`) and the tab
    /// that mounts on selection right after the import (`onAppear`).
    private func navigateToImportedIfNeeded() {
        guard let recipe = importedRecipe, categoryTypes.contains(recipe.type) else { return }
        path.append(RecipeRoute.recipe(id: recipe.id))
        importedRecipe = nil
        Task { await viewModel.load() }
    }
}

#Preview {
    HomeView(title: "Cuisine", categoryTypes: [.plat, .tmx], importedRecipe: .constant(nil))
}
