import SwiftUI

/// The Carnet home screen: "À tester" banners, the paginated library, and recent
/// activity. Pure presentation — navigation, pagination and API calls are owned by
/// `HomeView`. The "À tester" and recent-activity sections come from the `home`
/// read model (`data`); the library is a separate, server-sorted, infinitely
/// scrolling page (`library` + the `library*` flags and callbacks).
struct HomePage: View {
    /// The type filter offered on a multi-type tab (Carnet), rendered as round
    /// glass toolbar buttons — one per type (Plat / Thermomix). `nil` on a
    /// single-type tab, which needs no selector.
    struct TypeFilter {
        let options: [RecipeType]
        let selection: Binding<RecipeType>
    }

    let data: HomeData
    let library: [LibraryRecipe]
    /// `true` when the library is sorted by last modification (month sections);
    /// `false` for the dish-course sort (flat list).
    let libraryGrouped: Bool
    let libraryLoading: Bool
    let libraryHasMore: Bool
    let libraryLoadMoreFailed: Bool
    let title: String
    let typeFilter: TypeFilter?
    let sort: Binding<RecipeSortOption>
    /// Server-side dish-category facet, driven from the filter+sort menu. `nil` =
    /// every category.
    let categoryFilter: Binding<DishCategory?>
    let onExecute: (HomeTestItem) -> Void
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
                if let filter = typeFilter {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ForEach(filter.options) { type in
                            let isSelected = filter.selection.wrappedValue == type
                            Button {
                                filter.selection.wrappedValue = type
                            } label: {
                                type.iconImage(filled: false)
                            }
                            .tint(isSelected ? .accentColor : .primary)
                            .accessibilityLabel(type.label)
                            .accessibilityIdentifier("home-type-filter-\(type.rawValue)")
                        }
                    }
                    // Break out of the type-filter capsule so the filter+sort menu
                    // reads as its own control on Liquid Glass (otherwise they merge).
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

    /// Empty-carnet copy. A filter that yields nothing (a type segment or a dish
    /// category) isn't a first-run state — the tab may well hold other recipes — so
    /// only the genuinely empty, unfiltered carnet nudges the user to import.
    private var emptyStateMessage: String {
        if categoryFilter.wrappedValue != nil {
            return "Aucune recette dans cette catégorie pour l’instant."
        }
        if typeFilter != nil {
            return "Aucune recette de ce type pour l’instant."
        }
        return "Importe ta première recette depuis l’onglet Importer — photo, texte ou lien."
    }

    @ViewBuilder
    private var content: some View {
        if data.toTest.isEmpty && library.isEmpty {
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
                ToTestSection(items: data.toTest, onExecute: onExecute)
                LibrarySection(
                    recipes: library,
                    grouped: libraryGrouped,
                    hasMore: libraryHasMore,
                    loadMoreFailed: libraryLoadMoreFailed,
                    onPrefetch: onPrefetch,
                    onLoadMore: onLoadMore
                )
                RecentTrialsSection(trials: data.recentTrials, titleProvider: data.title(forRecipe:))
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

private struct HomePagePreview: View {
    @State private var selectedType: RecipeType = .plat
    @State private var sort: RecipeSortOption = .lastModified
    @State private var category: DishCategory?

    var body: some View {
        let data = HomeData(
            toTest: [
                .init(id: "1", title: "Bœuf bourguignon", type: .plat, category: .plat, versionNumber: 4, change: "Cuisson 3 h → 3 h 30", why: "Viande trop ferme."),
            ],
            library: [
                .init(id: "1", title: "Bœuf bourguignon", type: .plat, category: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, isDerived: false, updatedAt: Date()),
                .init(id: "2", title: "Velouté de courge", type: .tmx, category: .soupe, versionCount: 1, bestNote: 4, averageNote: 3.5, isDerived: false, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
            ],
            recentTrials: [
                .init(id: "t1", recipeId: "1", versionNumber: 3, note: 4, remarks: "Équilibré, fondant.", photoUrl: nil, executedAt: Date()),
            ]
        ).filtered(to: [selectedType])
        NavigationStack {
            HomePage(
                data: data,
                library: data.library,
                libraryGrouped: sort == .lastModified,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: "Cuisine",
                typeFilter: .init(options: [.plat, .tmx], selection: $selectedType),
                sort: $sort,
                categoryFilter: $category,
                onExecute: { _ in },
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
            data: Fixtures.homeData,
            library: Fixtures.homeData.library,
            libraryGrouped: true,
            libraryLoading: false,
            libraryHasMore: true,
            libraryLoadMoreFailed: false,
            title: "Cuisine",
            typeFilter: nil,
            sort: .constant(.lastModified),
            categoryFilter: .constant(nil),
            onExecute: { _ in },
            onSettings: {}
        )
    }
}
