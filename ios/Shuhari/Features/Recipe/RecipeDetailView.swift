import SwiftUI

/// Coordinator for the recipe fiche: loads the recipe, wires the execute cover
/// (through the binding owned by `HomeView`), the rename sheet, and deletion.
struct RecipeDetailView: View {
    let recipeId: String
    @Binding var path: NavigationPath
    let onReload: () -> Void

    @State private var viewModel: RecipeViewModel
    @State private var showEdit = false
    @State private var showToTest = false
    @State private var showHistory = false
    @State private var recordRequest: ExecutionRequest?
    @State private var showDeleteConfirm = false
    @State private var actionError = ErrorPresenter()

    init(
        recipeId: String,
        path: Binding<NavigationPath>,
        onReload: @escaping () -> Void
    ) {
        self.recipeId = recipeId
        self._path = path
        self.onReload = onReload
        self._viewModel = State(initialValue: RecipeViewModel(recipeId: recipeId))
    }

    var body: some View {
        Group {
            if let recipe = viewModel.recipe {
                RecipeDetailPage(recipe: recipe)
                .toolbar { toolbar(recipe: recipe) }
                // The fiche is a focused, Photos-style detail: hide the tab bar so the
                // floating action bar owns the bottom edge.
                .toolbar(.hidden, for: .tabBar)
                .sheet(isPresented: $showToTest) {
                    if let toTest = recipe.toTest {
                        ToTestSheet(
                            versionNumber: toTest.number,
                            change: toTest.change,
                            why: toTest.why ?? toTest.originDetail,
                            type: recipe.type
                        ) {
                            showToTest = false
                            presentRecordTrial(versionNumber: toTest.number)
                        }
                    }
                }
                // The record-trial flow as a half-screen sheet: capture at .medium,
                // grows to .large for the AI proposal.
                .sheet(item: $recordRequest) { request in
                    ExecuteFlowView(request: request, presentation: .sheet) {
                        onReload()
                        Task { await viewModel.load() }
                    }
                }
                .sheet(isPresented: $showHistory) {
                    HistorySheet(recipeId: recipeId) { onReload() }
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
    }

    @ToolbarContentBuilder
    private func toolbar(recipe: Recipe) -> some ToolbarContent {
        // Top-right: the more menu (edit / delete).
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

        // Floating glass action bar: à-tester (left) · record trial (centre) ·
        // history (right). The left slot keeps a hidden placeholder when no
        // pending version exists, so the centre CTA stays centred.
        ToolbarItem(placement: .bottomBar) {
            if recipe.toTest != nil {
                Button {
                    showToTest = true
                } label: {
                    Image(systemName: "flask.fill")
                }
                .accessibilityIdentifier("to-test-button")
                .accessibilityLabel("À tester")
            } else {
                Image(systemName: "flask.fill")
                    .hidden()
                    .accessibilityHidden(true)
            }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        if let reference = recipe.bestRatedVersion {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    presentRecordTrial(versionNumber: reference.number)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityIdentifier("record-trial-button")
                .accessibilityLabel("Noter un essai")
            }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("all-versions-button")
            .accessibilityLabel("Toutes les versions")
        }
    }

    private func presentRecordTrial(versionNumber: Int) {
        recordRequest = ExecutionRequest(
            recipeId: recipeId,
            versionNumber: versionNumber,
            startAtCapture: true
        )
    }
}
