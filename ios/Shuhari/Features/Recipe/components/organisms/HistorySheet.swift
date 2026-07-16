import SwiftUI

/// The full version history, presented as a sheet from the fiche's bottom bar:
/// every version, the trial journal and linked variations. Hosts its own
/// navigation stack so trial and variation links stay tappable inside the sheet.
struct HistorySheet: View {
    let recipeId: String
    let onReload: () -> Void

    @State private var path = NavigationPath()
    @State private var execution: ExecutionRequest?

    var body: some View {
        NavigationStack(path: $path) {
            HistoryView(recipeId: recipeId)
                .recipeFlow(path: $path, execution: $execution, onReload: onReload)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
