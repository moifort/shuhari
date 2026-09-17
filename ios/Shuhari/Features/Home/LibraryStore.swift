import Foundation

/// The paginated library read-model, backing both the notebook's recipe list and
/// the coffee tab's. Accumulates server pages of the `recipes(...)` query and
/// reloads page 0 whenever the sort or a facet changes. Mirrors the vinarium
/// `WineListViewModel` pattern: generation token against stale responses, prefetch
/// threshold for infinite scroll, a `LoadMoreRow` sentinel that flips to a retry
/// button on failure.
@MainActor @Observable
final class LibraryStore {
    /// Which recipe types this store reads — the one thing that tells the notebook
    /// (`RecipeType.cooking`) and the coffee tab (`[.coffee]`) apart. Fixed for the
    /// store's life: a tab never changes what it is about.
    private let types: [RecipeType]

    /// A library opens filed the way it is searched — by dish course, or by brew
    /// method for the coffee tab — with the favourites leading every section.
    init(types: [RecipeType] = RecipeType.cooking, sort: RecipeSortOption = .dishCategory) {
        self.types = types
        self.sort = sort
    }

    /// Pages accumulated from the server, in the current sort order.
    private(set) var items: [LibraryRecipe] = []
    /// Starts true to avoid a "Aucune recette" flash before the first load().
    var isLoading = true
    var isLoadingMore = false
    var hasMore = false
    /// Last loadMore failed: the sentinel becomes a "Réessayer" button instead of a
    /// spinner that would spin forever without retrying.
    private(set) var loadMoreFailed = false
    var error: String?

    /// Filed (by course or by method) vs. last-modified ordering. Any change reloads
    /// page 0.
    var sort: RecipeSortOption {
        didSet { if oldValue != sort { scheduleReload() } }
    }

    /// Server-side dish-category facet. `nil` = every category. Any change reloads.
    /// The page keeps the order `sort` asks for — one course reads like that section
    /// of the whole library.
    var category: DishCategory? {
        didSet { if oldValue != category { scheduleReload() } }
    }

    /// Server-side brew-method facet, the coffee tab's counterpart of `category`.
    /// `nil` = every method. Keeps the order `sort` asks for, like `category`.
    var method: BrewMethod? {
        didSet { if oldValue != method { scheduleReload() } }
    }

    /// What is typed in the search field. The first character fetches the index; the
    /// matching itself is local, so every keystroke after it answers at once.
    var searchText = "" {
        didSet { if index == nil, !searchText.isEmpty { loadIndex() } }
    }

    /// The recipes whose title holds `searchText` — `nil` while nothing is typed (the
    /// library shows), empty while the index is still on its way or matches nothing.
    var searchResults: [LibraryIndexEntry]? {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return LibraryIndexEntry.matching(searchText, in: index ?? [])
    }

    /// The index is on its way: the results are not "nothing found" yet.
    var isSearching: Bool { index == nil && indexTask != nil }

    /// Every recipe of the tab by name, fetched on the first search and dropped
    /// whenever the library reloads — a mutation may have renamed, added or removed one.
    private var index: [LibraryIndexEntry]?
    private var indexTask: Task<Void, Never>?

    private let pageSize = 20
    // Well below pageSize, otherwise the next page would load as soon as the first
    // appears (unintended chain loading).
    private let prefetchThreshold = 5
    private var reloadTask: Task<Void, Never>?
    // Stale-response guard: Apollo fetches aren't cancellable, so a response from a
    // previous sort/filter can arrive AFTER the current one. Each scheduleReload
    // invalidates earlier generations' responses.
    private var generation = 0

    /// Reload page 0, cancelling an in-flight reload (rapid filter changes). Empties
    /// the list and shows the loader so the view restarts from scratch. Called by the
    /// `didSet` hooks and by explicit refreshes.
    func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        items = []
        hasMore = false
        isLoadingMore = false // stale loadMores bail out without touching this
        loadMoreFailed = false
        isLoading = true
        reloadTask = Task { await load() }
    }

    /// Load the first page (on appear, pull-to-refresh, and after a mutation).
    /// Bumps the generation and clears the loadMore state — WITHOUT emptying `items`,
    /// so a pull-to-refresh doesn't flash — so any loadMore already in flight (its
    /// cursor points at the pre-refresh last row) fails its generation guard and can't
    /// append a stale page onto the fresh list.
    func load() async {
        dropIndex()
        generation += 1
        let requested = generation
        isLoadingMore = false
        loadMoreFailed = false
        isLoading = true
        error = nil
        do {
            let page = try await fetchPage(after: nil)
            guard requested == generation else { return } // response from a stale view
            items = page.items
            hasMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            self.error = reportError(error)
        }
        isLoading = false
    }

    /// Load the next page and append it to the recipes already loaded.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = items.last else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await fetchPage(after: last.id)
            guard requested == generation else { return }
            items.append(contentsOf: page.items)
            hasMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            loadMoreFailed = true
            self.error = reportError(error)
        }
        isLoadingMore = false
    }

    /// Delete a recipe optimistically, in the background: the row leaves the library at
    /// once — the recipe sheet closes without waiting — and the call follows. A failure
    /// is reported and the reload puts the recipe back where it was.
    func delete(recipeId: String) {
        items.removeAll { $0.id == recipeId }
        index?.removeAll { $0.id == recipeId }
        Task {
            do {
                try await RecipeAPI.deleteRecipe(id: recipeId)
            } catch {
                self.error = reportError(error)
                await load()
            }
        }
    }

    /// Delete one version in the background: the recipe sheet closes without waiting
    /// and the call follows. A failure is reported; the reload reflects whatever
    /// survived either way (the row's version count, its best rating).
    func deleteVersion(recipeId: String, number: Int) {
        Task {
            do {
                try await RecipeAPI.deleteVersion(recipeId: recipeId, number: number)
            } catch {
                self.error = reportError(error)
            }
            await load()
        }
    }

    /// Trigger the next page when a row near the end appears (infinite scroll).
    func prefetchIfNeeded(for recipeId: String) {
        guard hasMore, !isLoadingMore else { return }
        guard let index = items.firstIndex(where: { $0.id == recipeId }) else { return }
        if items.count - index <= prefetchThreshold {
            Task { await loadMore() }
        }
    }

    private func loadIndex() {
        guard indexTask == nil else { return }
        indexTask = Task {
            // A dropped index cancels this task: it must not land on top of its
            // replacement, nor clear the handle of the task that took over.
            do {
                let fetched = try await LibraryAPI.index(types: types)
                guard !Task.isCancelled else { return }
                index = fetched
            } catch {
                guard !Task.isCancelled else { return }
                self.error = reportError(error)
            }
            indexTask = nil
        }
    }

    /// Forget the index; a search still open fetches a fresh one right away.
    private func dropIndex() {
        indexTask?.cancel()
        indexTask = nil
        index = nil
        if !searchText.isEmpty { loadIndex() }
    }

    private func fetchPage(after: String?) async throws -> RecipePage {
        try await LibraryAPI.list(
            types: types,
            category: category,
            method: method,
            sort: sort,
            limit: pageSize,
            after: after
        )
    }
}
