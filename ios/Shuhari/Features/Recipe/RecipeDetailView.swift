import SwiftUI

/// Coordinator for the recipe fiche: loads the recipe, wires the execute cover
/// (through the binding owned by `HomeView`), the rename sheet, and deletion.
struct RecipeDetailView: View {
    let recipeId: String
    /// When set, the fiche focuses this version (the essai view): orange banner +
    /// per-row change dots. Nil renders the plain fiche.
    let focusVersionNumber: Int?
    @Binding var path: NavigationPath
    let onReload: () -> Void

    @State private var viewModel: RecipeViewModel
    @State private var showEdit = false
    @State private var showToTest = false
    @State private var showHistory = false
    @State private var recordRequest: ExecutionRequest?
    @State private var showDeleteConfirm = false
    @State private var actionError = ErrorPresenter()
    /// The version a "prochain essai" row picked: consumed on the sheet's dismiss
    /// so the navigation push isn't swallowed by the sheet teardown.
    @State private var previewVersion: Int?

    init(
        recipeId: String,
        focusVersionNumber: Int? = nil,
        path: Binding<NavigationPath>,
        onReload: @escaping () -> Void
    ) {
        self.recipeId = recipeId
        self.focusVersionNumber = focusVersionNumber
        self._path = path
        self.onReload = onReload
        self._viewModel = State(initialValue: RecipeViewModel(recipeId: recipeId))
    }

    /// Preview/gallery initializer: renders the full coordinator — action bar and
    /// sheets included — from a fixture recipe, with no network.
    init(
        previewRecipe: Recipe,
        path: Binding<NavigationPath>,
        onReload: @escaping () -> Void = {},
        focusVersionNumber: Int? = nil
    ) {
        self.recipeId = previewRecipe.id
        self.focusVersionNumber = focusVersionNumber
        self._path = path
        self.onReload = onReload
        self._viewModel = State(initialValue: RecipeViewModel(previewRecipe: previewRecipe))
    }

    var body: some View {
        Group {
            if let recipe = viewModel.recipe {
                detailPage(recipe: recipe)
                .toolbar { toolbar(recipe: recipe) }
                // The fiche is a focused, Photos-style detail: hide the tab bar so the
                // floating action bar owns the bottom edge.
                .toolbar(.hidden, for: .tabBar)
                .sheet(isPresented: $showToTest, onDismiss: {
                    // Sequence the push after the sheet is fully gone, so the
                    // path mutation isn't eaten by the dismissal.
                    if let version = previewVersion {
                        previewVersion = nil
                        path.append(RecipeRoute.essai(recipeId: recipeId, versionNumber: version))
                    }
                }) {
                    NextTrialsSheet(
                        trials: pendingEssaiItems(recipe),
                        onDelete: { versionNumber in
                            Task {
                                await actionError.run {
                                    try await RecipeAPI.discardPendingVersion(recipeId: recipeId, versionNumber: versionNumber)
                                } onSuccess: {
                                    onReload()
                                    Task { await viewModel.load() }
                                }
                            }
                        }
                    ) { versionNumber in
                        // Tapping a row closes the sheet, then navigates to the version.
                        previewVersion = versionNumber
                        showToTest = false
                    }
                }
                // The record-trial flow as a half-screen sheet: capture at .medium,
                // grows to .large for the AI draft.
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
                    Text("Toutes ses versions et essais seront supprimés. Action irréversible.")
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

    /// The fiche, focused on a version when `focusVersionNumber` is set (essai
    /// view: orange banner + per-row change dots vs the previous version), or the
    /// plain best-rated fiche otherwise.
    @ViewBuilder
    private func detailPage(recipe: Recipe) -> some View {
        if let number = focusVersionNumber, let focus = recipe.version(number) {
            let previous = recipe.version(number - 1)
            RecipeDetailPage(
                recipe: recipe,
                focusVersion: focus,
                modifiedIngredients: modifiedIngredients(focus, previous: previous),
                modifiedSteps: modifiedSteps(focus, previous: previous),
                change: focus.change,
                why: focus.why ?? focus.originDetail
            )
        } else {
            RecipeDetailPage(recipe: recipe)
        }
    }

    /// Ingredient names present in `version` but absent (by name + quantity) from
    /// `previous` — the rows that changed. No previous version → nothing changed.
    private func modifiedIngredients(_ version: RecipeVersion, previous: RecipeVersion?) -> Set<String> {
        guard let previous else { return [] }
        return Set(
            version.ingredients
                .filter { ingredient in
                    !previous.ingredients.contains { $0.name == ingredient.name && $0.quantity == ingredient.quantity }
                }
                .map(\.name)
        )
    }

    /// Step indices whose exact text is absent from `previous` — the rows that
    /// changed. No previous version → nothing changed.
    private func modifiedSteps(_ version: RecipeVersion, previous: RecipeVersion?) -> Set<Int> {
        guard let previous else { return [] }
        return Set(
            version.steps.enumerated()
                .filter { !previous.steps.contains($0.element) }
                .map(\.offset)
        )
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

        // Floating glass action bar: record trial (left), then the two
        // sheet openers — prochains essais + history — glued in one glass
        // group (no spacer between them).
        // Record targets the most recently created UNTRIED version (set-once: a tried
        // version can't be re-recorded). Hidden when every version is tried.
        if let next = nextRunnableVersion(recipe) {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    presentRecordTrial(versionNumber: next.number)
                } label: {
                    Image(systemName: "pencil.and.ruler")
                }
                .accessibilityIdentifier("record-trial-button")
                .accessibilityLabel("Noter un essai")
            }
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                showToTest = true
            } label: {
                Image(systemName: "flask")
                    .overlay(alignment: .topTrailing) {
                        if !recipe.pendingEssais.isEmpty {
                            Circle()
                                .fill(Theme.Status.toTest)
                                .frame(width: 7, height: 7)
                                .offset(x: 3, y: -2)
                        }
                    }
            }
            .accessibilityIdentifier("to-test-button")
            .accessibilityLabel("Prochains essais")
        }
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

    /// The pending-essai list for the sheet and the fiole badge, driven by the
    /// server field (already sorted, descending number; empty for an original-only
    /// recipe).
    private func pendingEssaiItems(_ recipe: Recipe) -> [NextTrialsSheet.Item] {
        recipe.pendingEssais.map {
            NextTrialsSheet.Item(
                versionNumber: $0.number,
                change: $0.change,
                why: $0.why ?? $0.originDetail
            )
        }
    }

    /// The version the record CTA targets: the most recently created untried
    /// version (client-side filter, so a lone v1 stays recordable).
    private func nextRunnableVersion(_ recipe: Recipe) -> RecipeVersion? {
        recipe.versions
            .filter { !$0.tried }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func presentRecordTrial(versionNumber: Int) {
        recordRequest = ExecutionRequest(
            recipeId: recipeId,
            versionNumber: versionNumber,
            startAtCapture: true
        )
    }
}
