import SwiftUI

/// Root once authenticated. Three category tabs (Cuisine = plats & Thermomix,
/// Café, Cocktail) plus an "Importer" entry pinned to the trailing side of the
/// tab bar (`.search` role): tapping it never switches tab — it opens the
/// camera-first import full-screen. On success the new recipe is routed to the
/// tab matching its type, which navigates to its fiche.
struct ContentView: View {
    enum RootTab: Hashable {
        case cuisine, cafe, cocktail, importer
    }

    @State private var selectedTab: RootTab = .cuisine
    @State private var showImport = false
    @State private var importedRecipe: ImportedRecipe?

    var body: some View {
        TabView(selection: $selectedTab) {
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
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .importer {
                selectedTab = oldValue
                showImport = true
            }
        }
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
