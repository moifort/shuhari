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
    @State private var lens: LibraryLens = .type(.dish)

    /// Multi-type tabs (cooking) offer the lens picker; single-type tabs don't.
    private var isMultiType: Bool { categoryTypes.count > 1 }

    /// The lenses in design order — the tab's types, then the favourites, which cut
    /// across all of them.
    private var lensOptions: [LibraryLens] {
        RecipeType.allCases.filter { categoryTypes.contains($0) }.map(LibraryLens.type) + [.favorites]
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
                        title: isMultiType ? lens.label : title,
                        lensPicker: isMultiType
                            ? .init(options: lensOptions, selection: $lens)
                            : nil,
                        sort: $library.sort,
                        categoryFilter: $library.category,
                        onSettings: { showSettings = true },
                        onPrefetch: { library.prefetchIfNeeded(for: $0) },
                        onLoadMore: { await library.loadMore() }
                    )
                }
            }
            .recipeFlow(
                path: $path,
                onReload: { Task { await reloadAll() } },
                onDelete: { library.delete(recipeId: $0) }
            )
        }
        .task {
            await loadLibraryIfNeeded()
        }
        .refreshable { await reloadAll() }
        .onChange(of: lens) { _, newValue in
            apply(newValue)
        }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView(onDataReplaced: { await reloadAll() })
        }
        .onChange(of: importedRecipe) { _, _ in navigateToImportedIfNeeded() }
        .onAppear { navigateToImportedIfNeeded() }
    }

    /// Point the library at a lens: its facets, and the order it opens on. On a
    /// single-type tab there is no lens picker, and the tab's own types apply.
    private func apply(_ lens: LibraryLens) {
        library.favorite = lens == .favorites
        library.type = isMultiType ? lens.recipeType : nil
        library.sort = lens.defaultSort
    }

    /// Kick off the first library page. The facets reload via their `didSet` when they
    /// change; on an unchanged lens (e.g. a single-type tab), load explicitly.
    private func loadLibraryIfNeeded() async {
        let before = (library.type, library.favorite, library.sort)
        apply(lens)
        if (library.type, library.favorite, library.sort) == before, library.items.isEmpty {
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
        if isMultiType { lens = .type(recipe.type) }
        path.append(RecipeRoute.recipe(id: recipe.id))
        importedRecipe = nil
        Task { await reloadAll() }
    }
}

#Preview {
    HomeView(title: "Cuisine", categoryTypes: [.dish, .thermomix], importedRecipe: .constant(nil))
}
