import SwiftUI

/// Coordinator for the AI proposal. Loads the recipe's pending proposal (plus the
/// context it needs to display), and applies the accept / refuse mutations.
struct ProposalView: View {
    let recipeId: String
    let onResolved: () -> Void

    @State private var recipe: Recipe?
    @State private var loadError: String?
    @State private var actionError = ErrorPresenter()

    var body: some View {
        Group {
            if let recipe, let proposal = recipe.pendingProposal {
                ProposalPage(
                    recipeTitle: recipe.title,
                    type: recipe.type,
                    proposal: proposal,
                    nextVersionNumber: recipe.nextVersionNumber,
                    variationTitle: proposal.variation?.title,
                    isWorking: actionError.isRunning,
                    onRefuse: {
                        Task {
                            await actionError.run {
                                try await ProposalAPI.refuse(recipeId: recipeId, versionNumber: proposal.versionNumber)
                            } onSuccess: { onResolved() }
                        }
                    },
                    onValidate: { choice, editedVars in
                        Task {
                            await actionError.run {
                                try await ProposalAPI.accept(
                                    recipeId: recipeId,
                                    versionNumber: proposal.versionNumber,
                                    choice: choice,
                                    editedVars: editedVars
                                )
                            } onSuccess: { onResolved() }
                        }
                    }
                )
            } else if recipe != nil {
                // Proposal already resolved elsewhere.
                ContentUnavailableView("Aucune proposition en attente", systemImage: "sparkles")
            } else if let loadError {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ProgressView()
            }
        }
        .errorAlert(actionError)
        .task { if recipe == nil { await load() } }
    }

    private func load() async {
        do {
            recipe = try await RecipeAPI.getRecipe(id: recipeId)
        } catch {
            loadError = reportError(error)
        }
    }
}
