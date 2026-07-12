import SwiftUI

/// Root of the "Carnet" tab. Owns the NavigationStack, the settings sheet and the
/// recipe flow (fiche → historique → essai → proposition + execution cover).
struct HomeView: View {
    @Binding var importedRecipeID: String?

    @State private var viewModel = HomeViewModel()
    @State private var path = NavigationPath()
    @State private var showSettings = false
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
                        onSettings: { showSettings = true }
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
        .sheet(isPresented: $showSettings) {
            SettingsHomeView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .carnetDataDidReload)) { _ in
            Task { await viewModel.load() }
        }
        .onChange(of: importedRecipeID) { _, newValue in
            guard let id = newValue else { return }
            path.append(RecipeRoute.recipe(id: id))
            importedRecipeID = nil
            Task { await viewModel.load() }
        }
    }
}

#Preview {
    HomeView(importedRecipeID: .constant(nil))
}
