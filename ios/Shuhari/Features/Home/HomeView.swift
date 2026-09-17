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
                        libraryHasMore: library.hasMore,
                        libraryLoadMoreFailed: library.loadMoreFailed,
                        title: "Cuisine",
                        sortOptions: RecipeSortOption.cooking,
                        sort: $library.sort,
                        facet: .course(selection: $library.category),
                        onSettings: { showSettings = true },
                        onPrefetch: { library.prefetchIfNeeded(for: $0) },
                        onLoadMore: { await library.loadMore() }
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
        .task {
            await loadLibraryIfNeeded()
        }
        .refreshable { await reloadAll() }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView(onDataReplaced: { await reloadAll() })
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    /// Kick off the first library page. The sort and the facet reload on their own
    /// (`didSet`) when they change.
    private func loadLibraryIfNeeded() async {
        if library.items.isEmpty {
            await library.load()
        }
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
        Task { await reloadAll() }
    }
}

#Preview {
    HomeView(importedRecipe: .constant(nil))
}
