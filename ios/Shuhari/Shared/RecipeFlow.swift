import SwiftUI

/// Resolves a `RecipeRoute` push into its screen. Shared by every tab that hosts
/// the recipe flow (Carnet and Importer), so navigation behaves identically.
struct RecipeRouteView: View {
    let route: RecipeRoute
    @Binding var path: NavigationPath
    let onReload: () -> Void

    var body: some View {
        switch route {
        case .recipe(let id):
            RecipeDetailView(recipeId: id, path: $path, onReload: onReload)
        case .history(let id):
            HistoryView(recipeId: id)
        case .essai(let recipeId, let versionNumber):
            TrialDetailView(recipeId: recipeId, versionNumber: versionNumber)
        }
    }
}

/// Installs the recipe push destinations and the execution full-screen cover.
struct RecipeFlowModifier: ViewModifier {
    @Binding var path: NavigationPath
    @Binding var execution: ExecutionRequest?
    let onReload: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: RecipeRoute.self) { route in
                RecipeRouteView(route: route, path: $path, onReload: onReload)
            }
            .fullScreenCover(item: $execution) { request in
                ExecuteFlowView(request: request) { onReload() }
            }
    }
}

extension View {
    func recipeFlow(
        path: Binding<NavigationPath>,
        execution: Binding<ExecutionRequest?>,
        onReload: @escaping () -> Void
    ) -> some View {
        modifier(RecipeFlowModifier(path: path, execution: execution, onReload: onReload))
    }
}
