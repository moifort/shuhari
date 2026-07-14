import SwiftUI

/// Coordinator for the recipe fiche: loads the recipe, wires the execute cover
/// (through the binding owned by `HomeView`), the rename sheet, and deletion.
struct RecipeDetailView: View {
    let recipeId: String
    @Binding var path: NavigationPath
    @Binding var execution: ExecutionRequest?
    let onReload: () -> Void

    @State private var viewModel: RecipeViewModel
    @State private var showEdit = false
    @State private var showIngredients = false
    @State private var showDeleteConfirm = false
    @State private var actionError = ErrorPresenter()

    init(
        recipeId: String,
        path: Binding<NavigationPath>,
        execution: Binding<ExecutionRequest?>,
        onReload: @escaping () -> Void
    ) {
        self.recipeId = recipeId
        self._path = path
        self._execution = execution
        self.onReload = onReload
        self._viewModel = State(initialValue: RecipeViewModel(recipeId: recipeId))
    }

    var body: some View {
        Group {
            if let recipe = viewModel.recipe {
                RecipeDetailPage(recipe: recipe, onExecute: startExecution)
                .toolbar { toolbar(recipe: recipe) }
                // The fiche is a focused, Photos-style detail: hide the tab bar so the
                // floating action bar owns the bottom edge.
                .toolbar(.hidden, for: .tabBar)
                .sheet(isPresented: $showIngredients) {
                    IngredientsSheet(ingredients: shoppingList(recipe))
                }
                .sheet(isPresented: $showEdit) {
                    RecipeEditSheet(
                        initialTitle: recipe.title,
                        initialSubtitle: recipe.subtitle ?? ""
                    ) { title, subtitle in
                        try await RecipeAPI.updateRecipe(id: recipeId, title: title, subtitle: subtitle)
                        await viewModel.load()
                    }
                }
                .alert("Supprimer cette recette ?", isPresented: $showDeleteConfirm) {
                    Button("Annuler", role: .cancel) {}
                    Button("Supprimer", role: .destructive) {
                        Task {
                            await actionError.run {
                                try await RecipeAPI.deleteRecipe(id: recipeId)
                            } onSuccess: {
                                onReload()
                                if !path.isEmpty { path.removeLast() }
                            }
                        }
                    }
                    .accessibilityIdentifier("confirm-delete-recipe")
                } message: {
                    Text("Toutes ses versions, essais et propositions seront supprimés. Action irréversible.")
                }
            } else if let error = viewModel.error {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
            }
        }
        .errorAlert(actionError)
        .task { if viewModel.recipe == nil { await viewModel.load() } }
        // Refresh when returning from the execute cover (post-trial state changed).
        .onChange(of: execution) { _, newValue in
            if newValue == nil { Task { await viewModel.load() } }
        }
    }

    @ToolbarContentBuilder
    private func toolbar(recipe: Recipe) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Modifier", systemImage: "pencil") { showEdit = true }
                Button("Supprimer", systemImage: "trash", role: .destructive) { showDeleteConfirm = true }
                    .accessibilityIdentifier("delete-recipe-button")
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityIdentifier("recipe-menu")
        }

        // Floating glass action bar: history · execute the current version · ingredients panel.
        // Each optional action carries its own leading spacer so no dangling separator
        // remains when it is absent.
        ToolbarItem(placement: .bottomBar) {
            NavigationLink(value: RecipeRoute.history(id: recipeId)) {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("history-link")
            .accessibilityLabel("Historique")
        }
        if let current = recipe.currentVersion {
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button {
                    startExecution(versionNumber: current.number)
                } label: {
                    Label("Exécuter la v\(current.number)", systemImage: "play.fill")
                }
                .accessibilityIdentifier("execute-current-button")
            }
        }
        if !shoppingList(recipe).isEmpty {
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showIngredients.toggle()
                } label: {
                    Label("Ingrédients", systemImage: "list.bullet")
                }
                .accessibilityIdentifier("ingredients-toggle")
            }
        }
    }

    private func startExecution(versionNumber: Int) {
        execution = ExecutionRequest(recipeId: recipeId, versionNumber: versionNumber)
    }

    /// Ingredients of the version the fiche shows as its reference — the current
    /// version, or the pending "to test" one when no reference exists yet.
    private func shoppingList(_ recipe: Recipe) -> [Ingredient] {
        (recipe.currentVersion ?? recipe.toTest)?.ingredients ?? []
    }
}
