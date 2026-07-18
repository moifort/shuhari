import SwiftUI

/// Root once authenticated. A single content tab, "Carnet" (all cuisine recipes —
/// plats & Thermomix), plus an "Importer" entry pinned to the trailing side of the
/// tab bar (`.search`/`.prominent` role — the only system affordance that keeps a
/// tab separated and visible while the bar minimises). Selecting it opens the
/// camera-first import full-screen; closing that cover restores the Carnet tab, so
/// the tab bar never lingers on the import entry's empty content. On success the
/// new recipe is routed to the Carnet, which navigates to its fiche.
struct ContentView: View {
    enum RootTab: Hashable {
        case carnet, importer
    }

    @State private var selectedTab: RootTab = .carnet
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
            Tab("Carnet", image: "toque", value: RootTab.carnet) {
                HomeView(title: "Carnet", categoryTypes: [.plat, .tmx], importedRecipe: $importedRecipe)
            }
            .accessibilityIdentifier("tab-carnet")

            Tab(value: RootTab.importer, role: importerTabRole) {
                Color.clear
            } label: {
                Label("Importer", systemImage: "camera")
            }
            .accessibilityIdentifier("tab-import")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .importer {
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
                    selectedTab = .carnet
                    reviewJob = nil
                },
                onCancel: { reviewJob = nil }
            )
            .presentationDetents([.large])
        }
    }

    /// When the camera cover closes: restore the Carnet tab, then — if the user
    /// picked a photo / captured / typed — present the review sheet over it, so
    /// the camera is fully gone rather than lingering behind the sheet.
    private func onImportCoverDismiss() {
        if selectedTab == .importer { selectedTab = .carnet }
        if let input = pendingImport {
            pendingImport = nil
            reviewJob = ImportJob(input: input)
        }
    }
}

#Preview {
    ContentView()
}
