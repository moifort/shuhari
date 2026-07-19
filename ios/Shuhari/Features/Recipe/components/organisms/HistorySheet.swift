import SwiftUI

/// The version history as a sheet over the recipe sheet: "Fermer" on the left, then
/// every version, newest first. Picking one hands its number back — the caller closes
/// the sheet and opens that version's recipe sheet in the stack behind, so the sheet
/// never pushes a screen of its own.
struct HistorySheet: View {
    let onSelect: (_ versionNumber: Int) -> Void

    @State private var viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss

    init(recipeId: String, onSelect: @escaping (_ versionNumber: Int) -> Void) {
        self.onSelect = onSelect
        self._viewModel = State(initialValue: RecipeViewModel(recipeId: recipeId))
    }

    /// Preview/gallery initializer: the sheet over a fixture recipe, with no network.
    init(previewRecipe: Recipe, onSelect: @escaping (_ versionNumber: Int) -> Void = { _ in }) {
        self.onSelect = onSelect
        self._viewModel = State(initialValue: RecipeViewModel(previewRecipe: previewRecipe))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let recipe = viewModel.recipe {
                    HistoryPage(recipe: recipe, onSelect: onSelect)
                } else if let error = viewModel.error {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityIdentifier("close-history-button")
                    .accessibilityLabel("Fermer")
                }
            }
        }
        .task { if viewModel.recipe == nil { await viewModel.load() } }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            HistorySheet(previewRecipe: Fixtures.bourguignon)
        }
}
