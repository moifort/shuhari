import SwiftUI

/// The coffee content tab. Same shape as `HomeView` — its own NavigationStack, the
/// settings sheet, the recipe flow and a `LibraryStore` — pointed at `[.coffee]`
/// instead of the cooking types. It opens grouped by brewing method, which is what
/// a coffee is filed by; the recipe flow underneath is type-agnostic and is reused
/// as is.
struct CoffeeView: View {
    @Binding var importedRecipe: ImportedRecipe?

    @State private var library = LibraryStore(types: [.coffee], sort: .brewMethod)
    /// The recipe flow's one state, for every screen the stack pushes.
    @State private var recipes = RecipeStore()
    @State private var path = NavigationPath()
    @State private var showSettings = false

    var body: some View {
        @Bindable var library = library
        NavigationStack(path: $path) {
            Group {
                // Full-screen error only on an empty first load — a transient
                // load-more failure keeps the populated list and surfaces through
                // the in-list "Réessayer" row instead.
                if let error = library.error, library.items.isEmpty {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    HomePage(
                        library: library.items,
                        // The sections follow the order: months under the date sort,
                        // methods otherwise — a single one when a method is picked.
                        libraryGrouping: library.sort == .lastModified ? .month : .method,
                        libraryLoading: library.isLoading,
                        libraryRefreshing: library.isRefreshing,
                        libraryRefreshFailed: library.refreshFailed,
                        libraryHasMore: library.hasMore,
                        libraryLoadMoreFailed: library.loadMoreFailed,
                        title: "Café",
                        sortOptions: RecipeSortOption.coffee,
                        sort: $library.sort,
                        facet: .method(selection: $library.method),
                        search: .init(
                            text: $library.searchText,
                            entries: library.searchResults,
                            loading: library.isSearching
                        ),
                        emptyFirstRunMessage: "Photographie une recette de café depuis l’onglet Importer — ou saisis-la.",
                        onSettings: { showSettings = true },
                        onPrefetch: { library.prefetchIfNeeded(for: $0) },
                        onLoadMore: { await library.loadMore() },
                        onRefresh: { await library.refresh() }
                    )
                }
            }
            .recipeFlow(
                store: recipes,
                path: $path,
                onReload: { Task { await reloadAll() } },
                onDelete: { library.delete(recipeId: $0) },
                onDeleteVersion: { library.deleteVersion(recipeId: $0, number: $1) }
            )
        }
        .task { await library.loadIfNeeded() }
        .refreshable { await reloadAll() }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView(onDataReplaced: { await reloadAll() })
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    private func reloadAll() async {
        await library.load()
    }

    /// Push the freshly imported coffee's recipe sheet. Handles both the
    /// already-mounted tab (`onChange`) and the tab that mounts on selection right
    /// after the import (`onAppear`).
    private func navigateToImportedIfNeeded() {
        guard let recipe = importedRecipe else { return }
        path.append(RecipeRoute.recipe(id: recipe.id))
        importedRecipe = nil
        Task { await reloadAll() }
    }
}

#Preview {
    CoffeeView(importedRecipe: .constant(nil))
}
