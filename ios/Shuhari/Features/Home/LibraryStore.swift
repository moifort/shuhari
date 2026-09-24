import Foundation

/// The paginated library read-model, backing both the notebook's recipe list and
/// the coffee tab's. Accumulates server pages of the `recipes(...)` query and
/// reloads page 0 whenever the sort or a facet changes. Mirrors the vinarium
/// `WineListViewModel` pattern: generation token against stale responses, prefetch
/// threshold for infinite scroll, a `LoadMoreRow` sentinel that flips to a retry
/// button on failure.
///
/// It opens on the page it closed on: `LibraryCache` hands back the last visit's rows
/// from disk before a single byte is asked of the network, so a relaunch shows the
/// library straight away and refreshes it underneath, silently — only a failed refresh
/// shows, as a retry row leading the list.
@MainActor @Observable
final class LibraryStore {
    /// Which recipe types this store reads — the one thing that tells the notebook
    /// (`RecipeType.cooking`) and the coffee tab (`[.coffee]`) apart. Fixed for the
    /// store's life: a tab never changes what it is about.
    private let types: [RecipeType]

    /// The order the tab opens on, and so the only one whose page 0 is worth keeping
    /// on disk: a library the cook re-sorted is a question they asked, not what the
    /// next launch should draw.
    private let openingSort: RecipeSortOption

    /// The tab's opening page on disk.
    private let cache: LibraryCache

    /// A library opens filed the way it is searched — by dish course, or by brew
    /// method for the coffee tab — with the favourites leading every section, and on
    /// the rows of the last visit when the disk still has them.
    init(types: [RecipeType] = RecipeType.cooking, sort: RecipeSortOption = .dishCategory) {
        self.types = types
        self.sort = sort
        openingSort = sort
        cache = LibraryCache(types: types)
        items = cache.read() ?? []
        // A cached library has nothing to wait for: it is already readable.
        isLoading = items.isEmpty
    }

    /// Pages accumulated from the server, in the current sort order.
    private(set) var items: [LibraryRecipe] = []
    /// Starts true to avoid a "Aucune recette" flash before the first load() — unless
    /// the cache opened the library, in which case there is nothing to wait for.
    var isLoading = true
    var isLoadingMore = false
    var hasMore = false
    /// Last loadMore failed: the sentinel becomes a "Réessayer" button instead of a
    /// spinner that would spin forever without retrying.
    private(set) var loadMoreFailed = false

    /// A library already on screen is being brought up to date, silently: the rows stay
    /// put and nothing spins. Only tells `refresh()` whether a sort or a facet change
    /// took the library over meanwhile.
    private var isRefreshing = false

    /// That refresh failed: the rows on screen are the ones from last time, and the
    /// leading row offers to try again — otherwise nothing would say they are stale.
    private(set) var refreshFailed = false

    /// Page 0 has come back from the server at least once, so appearing again is not a
    /// reason to fetch it anew.
    private var loaded = false

    /// Something changed while the library was out of sight — a recipe written, one
    /// imported. The next appearance reads page 0 again; nothing is fetched before.
    private var stale = false

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
        isRefreshing = false
        refreshFailed = false
        isLoading = true
        reloadTask = Task { await load() }
    }

    /// Load the first page (on appear, pull-to-refresh, and after a mutation).
    /// Bumps the generation and clears the loadMore state — WITHOUT emptying `items`,
    /// so a pull-to-refresh doesn't flash — so any loadMore already in flight (its
    /// cursor points at the pre-refresh last row) fails its generation guard and can't
    /// append a stale page onto the fresh list.
    func load() async {
        stale = false
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
            loaded = true
            refreshFailed = false
            saveCache()
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            self.error = reportError(error)
        }
        isLoading = false
    }

    /// The tab appeared: fetch page 0, once. With the cached library already on screen
    /// the rows stay and the refresh runs silently; with nothing to show, the
    /// flask owns the wait. Replaces the `items.isEmpty` test the tabs used to make,
    /// which a warm cache would have read as "already loaded".
    func loadIfNeeded() async {
        // A stale library is refreshed in place: the rows stay, and the few that moved
        // simply redraw — the cook is coming back to it, not opening it.
        if loaded {
            if stale { await load() }
            return
        }
        if items.isEmpty {
            await load()
        } else {
            await refresh()
        }
    }

    /// The library changed behind the screen showing it: read it again on the next
    /// appearance, once, however many writes happened in between.
    func invalidate() {
        stale = true
    }

    /// Bring the rows already on screen up to date without taking them away — the
    /// cached library's refresh, and the retry when that refresh failed.
    func refresh() async {
        isRefreshing = true
        refreshFailed = false
        await load()
        // A sort or a facet change took the library over meanwhile: it emptied the
        // rows and reset both flags, and this refresh no longer has anything to say.
        guard isRefreshing else { return }
        isRefreshing = false
        refreshFailed = !loaded
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
        // The row is gone for good and no reload follows a successful delete: the disk
        // must not bring it back on the next launch.
        saveCache()
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

    /// Keep the tab's opening page on disk — only when the library is showing exactly
    /// that: the opening order, no facet. A sorted or filtered page is not what the
    /// next launch opens on, and the file stays one page long however far the cook
    /// scrolled. Written off the main actor: the library is on screen already and has
    /// nothing to gain from waiting on a file.
    private func saveCache() {
        guard category == nil, method == nil, sort == openingSort else { return }
        let (cache, page) = (cache, Array(items.prefix(pageSize)))
        Task.detached { cache.write(page) }
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
