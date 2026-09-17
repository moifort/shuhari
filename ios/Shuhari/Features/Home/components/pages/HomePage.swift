import SwiftUI

/// A library home screen: the paginated recipe library. Pure presentation —
/// navigation, pagination and API calls are owned by `HomeView` (cooking) and
/// `CoffeeView`. The library is a server-sorted, infinitely scrolling page
/// (`library` + the `library*` flags and callbacks).
struct HomePage: View {
    /// The server-side facet of the filter+sort menu, in primitives: the page knows
    /// it is filtering on *something* with a label and an icon, not whether that
    /// something is a dish course or a brew method. Each tab passes its own.
    struct Facet {
        struct Option: Identifiable {
            let id: String
            let label: String
            let systemImage: String
        }

        /// The picker's own label, e.g. `"Catégorie"` or `"Méthode"`.
        let title: String
        /// What the "no facet" row reads, e.g. `"Toutes"`.
        let allLabel: String
        let options: [Option]
        /// The selected option's id — `nil` = no facet.
        let selection: Binding<String?>
    }

    /// The title search, in primitives. `results` is `nil` while nothing is typed —
    /// the library shows — and takes the list over as soon as something is.
    struct Search {
        struct Result: Identifiable {
            let id: String
            let title: String
            let icon: Image
            let iconLabel: String
            let favorite: Bool
        }

        let text: Binding<String>
        let results: [Result]?
        /// The index is still on its way: no results is not "nothing found" yet.
        var loading = false
    }

    let library: [LibraryRecipe]
    /// The library section axis: month of last update, dish course, or brew method.
    let libraryGrouping: LibraryGrouping
    let libraryLoading: Bool
    let libraryHasMore: Bool
    let libraryLoadMoreFailed: Bool
    let title: String
    /// The orders this tab offers — `RecipeSortOption.cooking` or `.coffee`.
    var sortOptions: [RecipeSortOption] = RecipeSortOption.cooking
    let sort: Binding<RecipeSortOption>
    let facet: Facet
    let search: Search
    /// Copy for the genuinely empty, unfiltered library — the first-run nudge.
    var emptyFirstRunMessage = "Importe ta première recette depuis l’onglet Importer — photo, texte ou lien."
    let onSettings: () -> Void
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    var body: some View {
        content
            .navigationTitle(title)
            .searchable(text: search.text, prompt: "Rechercher une recette")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("home-settings-button")
                    .accessibilityLabel("Réglages")
                }
                // The combined filter + sort menu.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Trier", selection: sort) {
                            ForEach(sortOptions) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }
                        Divider()
                        Picker(facet.title, selection: facet.selection) {
                            Label(facet.allLabel, systemImage: "circle.dashed")
                                .tag(String?.none)
                                .accessibilityIdentifier("library-facet-all")
                            ForEach(facet.options) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(String?.some(option.id))
                                    .accessibilityIdentifier("library-facet-\(option.id)")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .symbolVariant(facet.selection.wrappedValue != nil ? .fill : .none)
                    }
                    .accessibilityLabel("Filtrer et trier")
                    .accessibilityIdentifier("library-sort-menu")
                }
            }
    }

    /// Empty-library copy. A facet that yields nothing (a dish course, a brew
    /// method) isn't a first-run state — the library may well hold other
    /// recipes — so only the genuinely empty, unfiltered one nudges the user to import.
    private var emptyStateMessage: String {
        if facet.selection.wrappedValue != nil {
            return "Aucune recette dans cette catégorie pour l’instant."
        }
        return emptyFirstRunMessage
    }

    @ViewBuilder
    private var content: some View {
        if let results = search.results {
            if results.isEmpty, search.loading {
                ProgressView()
            } else if results.isEmpty {
                ContentUnavailableView.search(text: search.text.wrappedValue)
            } else {
                List(results) { result in
                    ZStack {
                        // A zero-opacity link keeps the row tappable without the chevron.
                        NavigationLink(value: RecipeRoute.recipe(id: result.id)) { EmptyView() }
                            .opacity(0)
                        LibrarySearchRow(
                            title: result.title,
                            icon: result.icon,
                            iconLabel: result.iconLabel,
                            favorite: result.favorite
                        )
                    }
                    .accessibilityIdentifier("search-result-\(result.id)")
                }
            }
        } else if library.isEmpty {
            if libraryLoading {
                // Cold functions make the first load slow: the looping flask
                // (fill → boil away → refill) owns the wait instead of a bare spinner.
                VStack(spacing: 16) {
                    LiquidFlask(size: 80, tint: .primary)
                    Text("Chargement des recettes…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView {
                    Label("Aucune recette", systemImage: "camera.viewfinder")
                } description: {
                    Text(emptyStateMessage)
                }
            }
        } else {
            List {
                LibrarySection(
                    recipes: library,
                    grouping: libraryGrouping,
                    hasMore: libraryHasMore,
                    loadMoreFailed: libraryLoadMoreFailed,
                    onPrefetch: onPrefetch,
                    onLoadMore: onLoadMore
                )
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

// MARK: - Search builder

extension HomePage.Search {
    /// Bridges the store's index entries to the page's primitives. A result wears what
    /// the recipe is filed by, like a library row: its brew method, else its course.
    init(text: Binding<String>, entries: [LibraryIndexEntry]?, loading: Bool) {
        self.init(
            text: text,
            results: entries?.map { entry in
                Result(
                    id: entry.id,
                    title: entry.title,
                    icon: entry.method?.iconImage ?? entry.category.iconImage,
                    iconLabel: entry.method?.label ?? entry.category.label,
                    favorite: entry.favorite
                )
            },
            loading: loading
        )
    }

    /// No search going on — previews and gallery screens.
    static var idle: Self { Self(text: .constant(""), results: nil) }
}

// MARK: - Facet builders

extension HomePage.Facet {
    /// The dish-course facet, bridging `DishCategory` to the page's primitives.
    static func course(selection: Binding<DishCategory?>) -> Self {
        Self(
            title: "Catégorie",
            allLabel: "Toutes",
            options: DishCategory.allCases.map {
                Option(id: $0.rawValue, label: $0.label, systemImage: $0.iconName)
            },
            selection: Binding(
                get: { selection.wrappedValue?.rawValue },
                set: { selection.wrappedValue = $0.flatMap(DishCategory.init(rawValue:)) }
            )
        )
    }

    /// The brew-method facet, the coffee tab's counterpart.
    static func method(selection: Binding<BrewMethod?>) -> Self {
        Self(
            title: "Méthode",
            allLabel: "Toutes",
            options: BrewMethod.allCases.map {
                Option(id: $0.rawValue, label: $0.label, systemImage: $0.iconName)
            },
            selection: Binding(
                get: { selection.wrappedValue?.rawValue },
                set: { selection.wrappedValue = $0.flatMap(BrewMethod.init(rawValue:)) }
            )
        )
    }
}

#if DEBUG
private struct HomePagePreview: View {
    @State private var sort: RecipeSortOption = .dishCategory
    @State private var category: DishCategory?

    var body: some View {
        NavigationStack {
            HomePage(
                library: Fixtures.libraryRecipes,
                libraryGrouping: sort == .lastModified ? .month : .course,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: "Cuisine",
                sort: $sort,
                facet: .course(selection: $category),
                search: .idle,
                onSettings: {}
            )
        }
    }
}

private struct CoffeePagePreview: View {
    @State private var sort: RecipeSortOption = .brewMethod
    @State private var method: BrewMethod?

    var body: some View {
        NavigationStack {
            HomePage(
                library: Fixtures.coffeeRecipes,
                libraryGrouping: sort == .lastModified ? .month : .method,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: "Café",
                sortOptions: RecipeSortOption.coffee,
                sort: $sort,
                facet: .method(selection: $method),
                search: .idle,
                onSettings: {}
            )
        }
    }
}

#Preview {
    HomePagePreview()
}

#Preview("Café") {
    CoffeePagePreview()
}

#Preview("Premier chargement") {
    NavigationStack {
        HomePage(
            library: [],
            libraryGrouping: .month,
            libraryLoading: true,
            libraryHasMore: false,
            libraryLoadMoreFailed: false,
            title: "Cuisine",
            sort: .constant(.lastModified),
            facet: .course(selection: .constant(nil)),
            search: .idle,
            onSettings: {}
        )
    }
}

#Preview("Chargement de plus") {
    NavigationStack {
        HomePage(
            library: Fixtures.libraryRecipes,
            libraryGrouping: .month,
            libraryLoading: false,
            libraryHasMore: true,
            libraryLoadMoreFailed: false,
            title: "Cuisine",
            sort: .constant(.lastModified),
            facet: .course(selection: .constant(nil)),
            search: .idle,
            onSettings: {}
        )
    }
}
#endif
