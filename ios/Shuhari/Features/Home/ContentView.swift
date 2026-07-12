import SwiftUI

/// Root once authenticated. Three category tabs (Cuisine = plats & Thermomix,
/// Café, Cocktail) plus an "Importer" entry pinned to the trailing side of the
/// tab bar (`.search` role — the only system affordance that keeps a tab
/// separated and visible while the bar minimises). Selecting it never becomes
/// the current tab: the selection binding intercepts it and opens the
/// camera-first import full-screen instead. On success the new recipe is
/// routed to the tab matching its type, which navigates to its fiche.
struct ContentView: View {
    enum RootTab: Hashable {
        case cuisine, cafe, cocktail, importer
    }

    @State private var selectedTab: RootTab = .cuisine
    @State private var showImport = false
    @State private var importedRecipe: ImportedRecipe?

    /// Routes the import "tab" to the full-screen cover without ever letting
    /// `selectedTab` land on it — no flicker, no placeholder content.
    private var tabSelection: Binding<RootTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .importer {
                    showImport = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Cuisine", systemImage: "fork.knife", value: RootTab.cuisine) {
                HomeView(title: "Cuisine", categoryTypes: [.plat, .tmx], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-cuisine")

            Tab("Café", systemImage: "cup.and.saucer", value: RootTab.cafe) {
                HomeView(title: "Café", categoryTypes: [.cafe], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-cafe")

            Tab("Cocktail", systemImage: "wineglass", value: RootTab.cocktail) {
                HomeView(title: "Cocktail", categoryTypes: [.cocktail], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-cocktail")

            Tab(value: RootTab.importer, role: .search) {
                Color.clear
            } label: {
                Label("Importer", systemImage: "camera")
                    .labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("tab-import")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(isPresented: $showImport) {
            ImportScanView { recipeId, type in
                importedRecipe = ImportedRecipe(id: recipeId, type: type)
                showImport = false
                selectedTab = Self.tab(for: type)
            }
        }
    }

    private static func tab(for type: RecipeType) -> RootTab {
        switch type {
        case .cafe: .cafe
        case .cocktail: .cocktail
        case .plat, .tmx: .cuisine
        }
    }
}

#Preview {
    ContentView()
}
