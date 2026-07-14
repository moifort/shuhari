import SwiftUI

/// Root once authenticated. Three category tabs (Cuisine = plats & Thermomix,
/// Café, Cocktail) plus an "Importer" entry pinned to the trailing side of the
/// tab bar (`.search` role — the only system affordance that keeps a tab
/// separated and visible while the bar minimises). Selecting it opens the
/// camera-first import full-screen; closing that cover restores the previously
/// selected category tab, so the tab bar never lingers on the import entry's
/// empty content. On success the new recipe is routed to the tab matching its
/// type, which navigates to its fiche.
struct ContentView: View {
    enum RootTab: Hashable {
        case cuisine, cafe, cocktail, importer
    }

    @State private var selectedTab: RootTab = .cuisine
    /// The last real content tab, restored when the import cover is dismissed.
    @State private var lastContentTab: RootTab = .cuisine
    @State private var showImport = false
    /// Set when the camera hands off a picked photo / capture / text: it closes
    /// the camera cover, then `onDismiss` presents the review sheet over the
    /// content tab (so the camera is gone, not lingering behind the sheet).
    @State private var pendingImport: ImportInput?
    @State private var reviewJob: ImportJob?
    @State private var importedRecipe: ImportedRecipe?
    @State private var store = HomeStore()

    /// The trailing "Importer" entry must stay detached from the content tabs.
    /// iOS 26 separates the `.search` role; iOS 27 folded `.search` back into the
    /// main tab row and introduced `.prominent` for a trailing-separated tab.
    /// Pick the role that detaches on the running OS, guarding `.prominent`
    /// behind the SDK that defines it (Swift 6.4 / Xcode 27) so the app still
    /// builds with Xcode 26.
    private var importerTabRole: TabRole {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return .prominent
        }
        #endif
        return .search
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Cuisine", image: "toque", value: RootTab.cuisine) {
                HomeView(title: "Cuisine", categoryTypes: [.plat, .tmx], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-cuisine")

            Tab("Café", systemImage: "mug", value: RootTab.cafe) {
                HomeView(title: "Café", categoryTypes: [.cafe], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-cafe")

            Tab("Cocktail", image: "cocktail", value: RootTab.cocktail) {
                HomeView(title: "Cocktail", categoryTypes: [.cocktail], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-cocktail")

            Tab(value: RootTab.importer, role: importerTabRole) {
                Color.clear
            } label: {
                Label("Importer", systemImage: "camera")
            }
            .accessibilityIdentifier("tab-import")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(store)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .importer {
                showImport = true
            } else {
                lastContentTab = newValue
            }
        }
        .fullScreenCover(isPresented: $showImport, onDismiss: onImportCoverDismiss) {
            ImportScanView { input in
                pendingImport = input
                showImport = false
            }
        }
        .sheet(item: $reviewJob) { job in
            ImportReviewSheet(
                input: job.input,
                onCreated: { recipeId, type in
                    importedRecipe = ImportedRecipe(id: recipeId, type: type)
                    selectedTab = Self.tab(for: type)
                    reviewJob = nil
                },
                onCancel: { reviewJob = nil }
            )
            .presentationDetents([.large])
        }
    }

    /// When the camera cover closes: restore the content tab, then — if the user
    /// picked a photo / captured / typed — present the review sheet over it, so
    /// the camera is fully gone rather than lingering behind the sheet.
    private func onImportCoverDismiss() {
        restoreContentTab()
        if let input = pendingImport {
            pendingImport = nil
            reviewJob = ImportJob(input: input)
        }
    }

    /// After the import cover closes, leave the empty "Importer" tab and go back
    /// to the category the user came from (unless a successful import already
    /// routed the selection to the new recipe's tab).
    private func restoreContentTab() {
        if selectedTab == .importer { selectedTab = lastContentTab }
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
