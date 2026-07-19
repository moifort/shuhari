import SwiftUI

/// The notebook content tab (cooking — dishes & Thermomix). Owns the
/// NavigationStack, the settings sheet and the recipe flow (recipe sheet → history →
/// attempt → proposal + execution cover), and a `LibraryStore` for the paginated,
/// server-sorted recipe library that fills the screen.
struct HomeView: View {
    let title: String
    let categoryTypes: Set<RecipeType>
    @Binding var importedRecipe: ImportedRecipe?

    @State private var library = LibraryStore()
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var selectedType: RecipeType = .dish

    /// Multi-type tabs (cooking) offer a segmented type filter; single-type tabs don't.
    private var isMultiType: Bool { categoryTypes.count > 1 }

    /// The type segments in design order — e.g. `[.dish, .thermomix]` for cooking.
    private var filterOptions: [RecipeType] {
        RecipeType.allCases.filter { categoryTypes.contains($0) }
    }

    var body: some View {
        @Bindable var library = library
        NavigationStack(path: $path) {
            Group {
                // Full-screen error only on an empty first load — a transient
                // load-more failure keeps the populated list and surfaces through
                // the in-list "Réessayer" row (libraryLoadMoreFailed) instead.
                if let error = library.error, library.items.isEmpty {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    HomePage(
                        library: library.items,
                        // Month sections apply whenever the effective order is
                        // chronological — that includes an active category filter,
                        // which the server coerces to updatedAt desc regardless of
                        // `sort` (and leaves a single course to section anyway).
                        libraryGrouping: library.sort == .lastModified || library.category != nil
                            ? .month
                            : .course,
                        libraryLoading: library.isLoading,
                        libraryHasMore: library.hasMore,
                        libraryLoadMoreFailed: library.loadMoreFailed,
                        title: isMultiType ? selectedType.label : title,
                        typeFilter: isMultiType
                            ? .init(options: filterOptions, selection: $selectedType)
                            : nil,
                        sort: $library.sort,
                        categoryFilter: $library.category,
                        onSettings: { showSettings = true },
                        onPrefetch: { library.prefetchIfNeeded(for: $0) },
                        onLoadMore: { await library.loadMore() }
                    )
                }
            }
            .recipeFlow(path: $path) {
                Task { await reloadAll() }
            }
        }
        .task {
            await loadLibraryIfNeeded()
        }
        .refreshable { await reloadAll() }
        .onChange(of: selectedType) { _, newValue in
            // On a single-type tab the filter is fixed to the tab's own types;
            // on notebook it drives the server-side `type` facet (its didSet reloads).
            library.type = isMultiType ? newValue : nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView(onDataReplaced: { await reloadAll() })
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

    /// Reload the library after a mutation, pull-to-refresh, or a new import.
    private func reloadAll() async {
        await library.load()
    }

    /// Push the freshly imported recipe's recipe sheet — but only in the tab that owns
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
    HomeView(title: "Cuisine", categoryTypes: [.dish, .thermomix], importedRecipe: .constant(nil))
}
