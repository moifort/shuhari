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
                RecipeDetailPage(recipe: recipe) { versionNumber in
                    execution = ExecutionRequest(recipeId: recipeId, versionNumber: versionNumber)
                }
                .toolbar { toolbar(recipe: recipe) }
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
            NavigationLink(value: RecipeRoute.history(id: recipeId)) {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("history-link")
            .accessibilityLabel("Historique")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
    }
}
