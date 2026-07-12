import SwiftUI

/// Root once authenticated. A "Carnet" tab plus an "Importer" entry pinned to
/// the trailing side of the tab bar (`.search` role): tapping it never switches
/// tab — it opens the camera-first import full-screen. On success the new
/// recipe id is routed into the Carnet, which navigates to its fiche.
struct ContentView: View {
    enum RootTab: Hashable {
        case carnet, importer
    }

    @State private var selectedTab: RootTab = .carnet
    @State private var showImport = false
    @State private var importedRecipeID: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Carnet", systemImage: "book", value: RootTab.carnet) {
                HomeView(importedRecipeID: $importedRecipeID)
            }
            .accessibilityIdentifier("tab-carnet")

            Tab(value: RootTab.importer, role: .search) {
                Color.clear
            } label: {
                Label("Importer", systemImage: "camera")
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
            ImportScanView { recipeId in
                importedRecipeID = recipeId
                showImport = false
                selectedTab = .carnet
            }
        }
    }
}

#Preview {
    ContentView()
}
