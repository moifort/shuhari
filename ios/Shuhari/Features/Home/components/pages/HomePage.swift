import SwiftUI

/// The notebook home screen: the paginated recipe library. Pure presentation —
/// navigation, pagination and API calls are owned by `HomeView`. The library is a
/// server-sorted, infinitely scrolling page (`library` + the `library*` flags and
/// callbacks).
struct HomePage: View {
    /// The lens picker offered on a multi-type tab (notebook), rendered as round
    /// glass toolbar buttons — one per recipe type, then the favourites. `nil` on a
    /// single-type tab, which needs no selector.
    struct LensPicker {
        let options: [LibraryLens]
        let selection: Binding<LibraryLens>
    }

    let library: [LibraryRecipe]
    /// The library section axis: month of last update, or dish course.
    let libraryGrouping: LibraryGrouping
    let libraryLoading: Bool
    let libraryHasMore: Bool
    let libraryLoadMoreFailed: Bool
    let title: String
    let lensPicker: LensPicker?
    let sort: Binding<RecipeSortOption>
    /// Server-side dish-category facet, driven from the filter+sort menu. `nil` =
    /// every category.
    let categoryFilter: Binding<DishCategory?>
    let onSettings: () -> Void
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    var body: some View {
        content
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("home-settings-button")
                    .accessibilityLabel("Réglages")
                }
                if let picker = lensPicker {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ForEach(picker.options) { lens in
                            let isSelected = picker.selection.wrappedValue == lens
                            Button {
                                picker.selection.wrappedValue = lens
                            } label: {
                                lens.iconImage(filled: isSelected)
                            }
                            .tint(isSelected ? lens.selectedTint : .primary)
                            .accessibilityLabel(lens.label)
                            .accessibilityIdentifier("home-lens-\(lens.id)")
                        }
                    }
                    // Break out of the lens capsule so the filter+sort menu reads as
                    // its own control on Liquid Glass (otherwise they merge).
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                // The combined filter + sort menu, detached from the type filter.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Trier", selection: sort) {
                            ForEach(RecipeSortOption.allCases) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }
                        Divider()
                        Picker("Catégorie", selection: categoryFilter) {
                            Label("Toutes", systemImage: "circle.dashed")
                                .tag(DishCategory?.none)
                                .accessibilityIdentifier("library-category-all")
                            ForEach(DishCategory.allCases) { category in
                                Label(category.label, systemImage: category.iconName)
                                    .tag(DishCategory?.some(category))
                                    .accessibilityIdentifier("library-category-\(category.rawValue)")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .symbolVariant(categoryFilter.wrappedValue != nil ? .fill : .none)
                    }
                    .accessibilityLabel("Filtrer et trier")
                    .accessibilityIdentifier("library-sort-menu")
                }
            }
    }

    /// Empty-notebook copy. A filter that yields nothing (a type segment or a dish
    /// category) isn't a first-run state — the tab may well hold other recipes — so
    /// only the genuinely empty, unfiltered notebook nudges the user to import.
    private var emptyStateMessage: String {
        if categoryFilter.wrappedValue != nil {
            return "Aucune recette dans cette catégorie pour l’instant."
        }
        if lensPicker?.selection.wrappedValue == .favorites {
            return "Aucun favori pour l’instant — ajoute-les depuis la fiche d’une recette."
        }
        // The `.all` lens narrows nothing: an empty library there IS the first-run state.
        if lensPicker != nil, lensPicker?.selection.wrappedValue != .all {
            return "Aucune recette de ce type pour l’instant."
        }
        return "Importe ta première recette depuis l’onglet Importer — photo, texte ou lien."
    }

    @ViewBuilder
    private var content: some View {
        if library.isEmpty {
            if libraryLoading {
                ProgressView()
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

private struct HomePagePreview: View {
    @State private var lens: LibraryLens = .all
    @State private var sort: RecipeSortOption = .lastModified
    @State private var category: DishCategory?

    var body: some View {
        let library = Fixtures.libraryRecipes.filter { recipe in
            switch lens {
            case .all: true
            case .favorites: recipe.favorite
            case .type(let type): recipe.type == type
            }
        }
        NavigationStack {
            HomePage(
                library: library,
                libraryGrouping: sort == .lastModified ? .month : .course,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: "Cuisine",
                lensPicker: .init(options: [.all, .type(.dish), .type(.thermomix), .favorites], selection: $lens),
                sort: $sort,
                categoryFilter: $category,
                onSettings: {}
            )
        }
    }
}

#Preview {
    HomePagePreview()
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
            lensPicker: nil,
            sort: .constant(.lastModified),
            categoryFilter: .constant(nil),
            onSettings: {}
        )
    }
}
