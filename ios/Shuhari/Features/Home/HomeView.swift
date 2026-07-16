import SwiftUI

/// One category tab of the Carnet (Cuisine / Café / Cocktail). Owns the
/// NavigationStack, the settings sheet and the recipe flow (fiche → historique →
/// essai → proposition + execution cover). Reads the shared `HomeStore` from the
/// environment and filters it to `categoryTypes`.
struct HomeView: View {
    let title: String
    let categoryTypes: Set<RecipeType>
    @Binding var importedRecipe: ImportedRecipe?

    @Environment(HomeStore.self) private var store
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var execution: ExecutionRequest?
    @State private var selectedType: RecipeType = .plat

    /// Multi-type tabs (Cuisine) offer a segmented type filter; single-type tabs don't.
    private var isMultiType: Bool { categoryTypes.count > 1 }

    /// The type segments in design order — e.g. `[.plat, .tmx]` for Cuisine.
    private var filterOptions: [RecipeType] {
        RecipeType.allCases.filter { categoryTypes.contains($0) }
    }

    /// On a multi-type tab, narrow the data to the selected segment; otherwise show
    /// every type the tab owns.
    private var effectiveTypes: Set<RecipeType> {
        isMultiType ? [selectedType] : categoryTypes
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let data = store.data {
                    HomePage(
                        data: data.filtered(to: effectiveTypes),
                        title: isMultiType ? selectedType.label : title,
                        typeFilter: isMultiType
                            ? .init(options: filterOptions, selection: $selectedType)
                            : nil,
                        onExecute: { item in
                            execution = ExecutionRequest(recipeId: item.id, versionNumber: item.versionNumber)
                        },
                        onSettings: { showSettings = true }
                    )
                } else if let error = store.error {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView()
                }
            }
            .recipeFlow(path: $path, execution: $execution) {
                Task { await store.load() }
            }
        }
        .task {
            if store.data == nil { await store.load() }
        }
        .refreshable { await store.load() }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView()
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    /// Push the freshly imported recipe's fiche — but only in the tab that owns
    /// its type. Handles both the already-mounted tab (`onChange`) and the tab
    /// that mounts on selection right after the import (`onAppear`).
    private func navigateToImportedIfNeeded() {
        guard let recipe = importedRecipe, categoryTypes.contains(recipe.type) else { return }
        if isMultiType { selectedType = recipe.type }
        path.append(RecipeRoute.recipe(id: recipe.id))
        importedRecipe = nil
        Task { await store.load() }
    }
}

#Preview {
    HomeView(title: "Cuisine", categoryTypes: [.plat, .tmx], importedRecipe: .constant(nil))
        .environment(HomeStore())
}
