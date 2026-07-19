import SwiftUI

/// Root once authenticated. A single content tab, "Carnet" (all cooking recipes —
/// dishes & Thermomix), plus an "Importer" entry pinned to the trailing side of the
/// tab bar (`.search`/`.prominent` role — the only system affordance that keeps a
/// tab separated and visible while the bar minimises). Selecting it opens the
/// camera-first import full-screen; closing that cover restores the notebook tab, so
/// the tab bar never lingers on the import entry's empty content. On success the
/// new recipe is routed to the notebook, which navigates to its recipe sheet.
struct ContentView: View {
    enum RootTab: Hashable {
        case notebook, importEntry
    }

    @State private var selectedTab: RootTab = .notebook
    @State private var showImport = false
    /// Set when the camera hands off a picked photo / capture / text: it closes
    /// the camera cover, then `onDismiss` presents the review sheet over the
    /// content tab (so the camera is gone, not lingering behind the sheet).
    @State private var pendingImport: ImportInput?
    @State private var reviewJob: ImportJob?
    @State private var importedRecipe: ImportedRecipe?

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
            Tab("Carnet", image: "toque", value: RootTab.notebook) {
                HomeView(title: "Carnet", categoryTypes: [.dish, .thermomix], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-notebook")

            Tab(value: RootTab.importEntry, role: importerTabRole) {
                Color.clear
            } label: {
                Label("Importer", systemImage: "camera")
            }
            .accessibilityIdentifier("tab-import")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .importEntry {
                showImport = true
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
                    selectedTab = .notebook
                    reviewJob = nil
                },
                onCancel: { reviewJob = nil }
            )
            .presentationDetents([.large])
        }
    }

    /// When the camera cover closes: restore the notebook tab, then — if the user
    /// picked a photo / captured / typed — present the review sheet over it, so
    /// the camera is fully gone rather than lingering behind the sheet.
    private func onImportCoverDismiss() {
        if selectedTab == .importEntry { selectedTab = .notebook }
        if let input = pendingImport {
            pendingImport = nil
            reviewJob = ImportJob(input: input)
        }
    }
}

#Preview {
    ContentView()
}
