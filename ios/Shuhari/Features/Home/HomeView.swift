import SwiftUI

/// The notebook content tab (cooking — dishes & Thermomix). Owns the
/// NavigationStack, the settings sheet and the recipe flow (recipe sheet → history →
/// version → proposal + execution cover), and a `LibraryStore` for the paginated,
/// server-sorted recipe library that fills the screen.
struct HomeView: View {
    @Binding var importedRecipe: ImportedRecipe?

    @State private var library = LibraryStore()
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
                // the in-list "Réessayer" row (libraryLoadMoreFailed) instead.
                if let error = library.error, library.items.isEmpty {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    HomePage(
                        library: library.items,
                        // The sections follow the order: months under the date sort,
                        // courses otherwise — a single one when a category is picked.
                        libraryGrouping: library.sort == .lastModified ? .month : .course,
                        libraryLoading: library.isLoading,
                        libraryRefreshFailed: library.refreshFailed,
                        libraryHasMore: library.hasMore,
                        libraryLoadMoreFailed: library.loadMoreFailed,
                        title: "Cuisine",
                        sortOptions: RecipeSortOption.cooking,
                        sort: $library.sort,
                        facet: .course(selection: $library.category),
                        search: .init(
                            text: $library.searchText,
                            entries: library.searchResults,
                            loading: library.isSearching
                        ),
                        onSettings: { showSettings = true },
                        onPrefetch: { library.prefetchIfNeeded(for: $0) },
                        onLoadMore: { await library.loadMore() },
                        onRefresh: { await library.refresh() }
                    )
                }
            }
            // On the stack's root, not on the stack: it runs again each time the cook
            // comes back to the library, which is when a stale one is read anew.
            .task { await library.loadIfNeeded() }
            .recipeFlow(
                store: recipes,
                path: $path,
                // The library is behind the recipe, out of sight: it is marked stale
                // and read once on the way back, not once per mutation.
                onReload: { library.invalidate() },
                onDelete: { library.delete(recipeId: $0) },
                onDeleteVersion: { library.deleteVersion(recipeId: $0, number: $1) }
            )
        }
        .refreshable { await reloadAll() }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView(onDataReplaced: { await reloadAll() })
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    /// Reload the library after a mutation, pull-to-refresh, or a new import.
    private func reloadAll() async {
        await library.load()
    }

    /// Push the freshly imported recipe's recipe sheet. Handles both the
    /// already-mounted tab (`onChange`) and the tab that mounts on selection right
    /// after the import (`onAppear`).
    private func navigateToImportedIfNeeded() {
        guard let recipe = importedRecipe else { return }
        path.append(RecipeRoute.recipe(id: recipe.id))
        importedRecipe = nil
        library.invalidate()
    }
}

#Preview {
    HomeView(importedRecipe: .constant(nil))
}
