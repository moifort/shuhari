import SwiftUI

/// The Carnet content tab (cuisine — plats & Thermomix). Owns the
/// NavigationStack, the settings sheet and the recipe flow (fiche → historique →
/// essai → proposition + execution cover). Reads the shared `HomeStore` (the
/// `home` read model behind the "À tester" and recent-activity sections) from the
/// environment, and owns a `LibraryStore` for the paginated, server-sorted library.
struct HomeView: View {
    let title: String
    let categoryTypes: Set<RecipeType>
    @Binding var importedRecipe: ImportedRecipe?

    @Environment(HomeStore.self) private var store
    @State private var library = LibraryStore()
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

    /// On a multi-type tab, narrow the home read model to the selected segment;
    /// otherwise show every type the tab owns. (The library is filtered server-side
    /// via `library.type`.)
    private var effectiveTypes: Set<RecipeType> {
        isMultiType ? [selectedType] : categoryTypes
    }

    var body: some View {
        @Bindable var library = library
        NavigationStack(path: $path) {
            Group {
                if let data = store.data {
                    HomePage(
                        data: data.filtered(to: effectiveTypes),
                        library: library.items,
                        // Month sections apply whenever the effective order is
                        // chronological — that includes an active category filter,
                        // which the server coerces to updatedAt desc regardless of
                        // `sort` (so a dish-category sort request there still groups).
                        libraryGrouped: library.sort == .lastModified || library.category != nil,
                        libraryLoading: library.isLoading,
                        libraryHasMore: library.hasMore,
                        libraryLoadMoreFailed: library.loadMoreFailed,
                        title: isMultiType ? selectedType.label : title,
                        typeFilter: isMultiType
                            ? .init(options: filterOptions, selection: $selectedType)
                            : nil,
                        sort: $library.sort,
                        categoryFilter: $library.category,
                        onExecute: { item in
                            execution = ExecutionRequest(recipeId: item.id, versionNumber: item.versionNumber)
                        },
                        onSettings: { showSettings = true },
                        onPrefetch: { library.prefetchIfNeeded(for: $0) },
                        onLoadMore: { await library.loadMore() }
                    )
                } else if let error = store.error {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView()
                }
            }
            .recipeFlow(path: $path, execution: $execution) {
                Task { await reloadAll() }
            }
        }
        .task {
            if store.data == nil { await store.load() }
            await loadLibraryIfNeeded()
        }
        .refreshable { await reloadAll() }
        .onChange(of: selectedType) { _, newValue in
            // On a single-type tab the filter is fixed to the tab's own types;
            // on Carnet it drives the server-side `type` facet (its didSet reloads).
            library.type = isMultiType ? newValue : nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView()
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    /// Kick off the first library page. Setting `type` reloads via its `didSet` when
    /// it changes; on an unchanged type (e.g. a single-type tab), load explicitly.
    private func loadLibraryIfNeeded() async {
        let wanted: RecipeType? = isMultiType ? selectedType : nil
        if library.type != wanted {
            library.type = wanted
        } else if library.items.isEmpty {
            await library.load()
        }
    }

    /// Reload both read models after a mutation, pull-to-refresh, or a new import —
    /// the library is paginated and separate, so it must be reloaded alongside `home`.
    private func reloadAll() async {
        async let home: Void = store.load()
        async let lib: Void = library.load()
        _ = await (home, lib)
    }

    /// Push the freshly imported recipe's fiche — but only in the tab that owns
    /// its type. Handles both the already-mounted tab (`onChange`) and the tab
    /// that mounts on selection right after the import (`onAppear`).
    private func navigateToImportedIfNeeded() {
        guard let recipe = importedRecipe, categoryTypes.contains(recipe.type) else { return }
        if isMultiType { selectedType = recipe.type }
        path.append(RecipeRoute.recipe(id: recipe.id))
        importedRecipe = nil
        Task { await reloadAll() }
    }
}

#Preview {
    HomeView(title: "Cuisine", categoryTypes: [.plat, .tmx], importedRecipe: .constant(nil))
        .environment(HomeStore())
}
