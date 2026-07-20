import SwiftUI

/// Resolves a `RecipeRoute` push into its screen. Shared by every tab that hosts
/// the recipe flow (notebook and Importer), so navigation behaves identically.
struct RecipeRouteView: View {
    let route: RecipeRoute
    @Binding var path: NavigationPath
    let onReload: () -> Void
    let onDelete: (String) -> Void
    let onDeleteVersion: (String, Int) -> Void

    var body: some View {
        switch route {
        case .recipe(let id):
            RecipeDetailView(
                recipeId: id,
                path: $path,
                onReload: onReload,
                onDelete: onDelete,
                onDeleteVersion: onDeleteVersion
            )
        case .attempt(let recipeId, let versionNumber):
            // The attempt reuses the recipe sheet, focused on the version: same
            // title, sections and CTAs, plus an orange banner and change dots.
            RecipeDetailView(
                recipeId: recipeId,
                focusVersionNumber: versionNumber,
                path: $path,
                onReload: onReload,
                onDelete: onDelete,
                onDeleteVersion: onDeleteVersion
            )
        }
    }
}

/// Installs the recipe push destinations and the execution full-screen cover.
struct RecipeFlowModifier: ViewModifier {
    @Binding var path: NavigationPath
    @Binding var execution: ExecutionRequest?
    let onReload: () -> Void
    let onDelete: (String) -> Void
    let onDeleteVersion: (String, Int) -> Void

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: RecipeRoute.self) { route in
                RecipeRouteView(
                    route: route,
                    path: $path,
                    onReload: onReload,
                    onDelete: onDelete,
                    onDeleteVersion: onDeleteVersion
                )
            }
            .fullScreenCover(item: $execution) { request in
                ExecuteFlowView(request: request) { onReload() }
            }
    }
}

extension View {
    func recipeFlow(
        path: Binding<NavigationPath>,
        execution: Binding<ExecutionRequest?> = .constant(nil),
        onReload: @escaping () -> Void,
        onDelete: @escaping (String) -> Void,
        onDeleteVersion: @escaping (String, Int) -> Void
    ) -> some View {
        modifier(RecipeFlowModifier(
            path: path,
            execution: execution,
            onReload: onReload,
            onDelete: onDelete,
            onDeleteVersion: onDeleteVersion
        ))
    }
}
