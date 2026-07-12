import SwiftUI

/// Root of the Carnet. Owns the NavigationStack, the settings and import sheets,
/// and the recipe flow (fiche → historique → essai → proposition + execution cover).
struct HomeView: View {
    /// The two modal sheets reachable from the Carnet toolbar, driven through a
    /// single `.sheet(item:)` so only one presents at a time.
    private enum ActiveSheet: Identifiable {
        case settings, importRecipe
        var id: Int { hashValue }
    }

    @State private var viewModel = HomeViewModel()
    @State private var path = NavigationPath()
    @State private var activeSheet: ActiveSheet?
    @State private var execution: ExecutionRequest?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let data = viewModel.data {
                    HomePage(
                        data: data,
                        onExecute: { item in
                            execution = ExecutionRequest(recipeId: item.id, versionNumber: item.versionNumber)
                        },
                        onImport: { activeSheet = .importRecipe },
                        onSettings: { activeSheet = .settings }
                    )
                } else if let error = viewModel.error {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView("Chargement…")
                }
            }
            .recipeFlow(path: $path, execution: $execution) {
                Task { await viewModel.load() }
            }
        }
        .task {
            if viewModel.data == nil { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsHomeView()
            case .importRecipe:
                ImportView { recipeId in
                    path.append(RecipeRoute.recipe(id: recipeId))
                    Task { await viewModel.load() }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .carnetDataDidReload)) { _ in
            Task { await viewModel.load() }
        }
    }
}

#Preview {
    HomeView()
}
