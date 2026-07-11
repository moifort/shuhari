import SwiftUI

/// Coordinator for a trial's detail. Loads the trial, then the parent recipe to
/// resolve the version's target parameters (needed for the comparison table and
/// for replay).
struct TrialDetailView: View {
    let trialId: String
    @Binding var execution: ExecutionRequest?

    @State private var trial: Trial?
    @State private var recipe: Recipe?
    @State private var error: String?

    var body: some View {
        Group {
            if let trial, let recipe {
                TrialDetailPage(
                    recipeTitle: recipe.title,
                    trial: trial,
                    versionTargets: recipe.version(trial.versionNumber)?.params ?? [],
                    onReplay: {
                        execution = ExecutionRequest(
                            recipeId: trial.recipeId,
                            versionNumber: trial.versionNumber,
                            replayTrialId: trial.id
                        )
                    }
                )
            } else if let error {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
            }
        }
        .task { if trial == nil { await load() } }
    }

    private func load() async {
        do {
            let loadedTrial = try await RecipeAPI.getTrial(id: trialId)
            trial = loadedTrial
            recipe = try await RecipeAPI.getRecipe(id: loadedTrial.recipeId)
        } catch {
            self.error = reportError(error)
        }
    }
}
