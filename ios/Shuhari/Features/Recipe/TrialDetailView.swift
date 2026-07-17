import SwiftUI

/// Coordinator for a trial's detail. Loads the trial, then the parent recipe to
/// resolve its title.
struct TrialDetailView: View {
    let trialId: String

    @State private var trial: Trial?
    @State private var recipeTitle: String?
    @State private var error: String?

    var body: some View {
        Group {
            if let trial, let recipeTitle {
                TrialDetailPage(recipeTitle: recipeTitle, trial: trial)
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
            recipeTitle = try await RecipeAPI.getRecipe(id: loadedTrial.recipeId).title
        } catch {
            self.error = reportError(error)
        }
    }
}
