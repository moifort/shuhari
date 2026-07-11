import Foundation

/// Push destinations inside the Carnet `NavigationStack`.
enum RecipeRoute: Hashable {
    case recipe(id: String)
    case history(id: String)
    case trial(id: String)
    case proposal(recipeId: String)
}

/// A request to run the execution flow (presented as a full-screen cover).
/// `replayTrialId` reinjects a past trial's real parameters (replay mode).
struct ExecutionRequest: Identifiable, Hashable {
    let recipeId: String
    let versionNumber: Int
    var replayTrialId: String?

    var id: String { "\(recipeId)#\(versionNumber)#\(replayTrialId ?? "")" }
}

/// Identifiable wrapper to drive a `.sheet(item:)` from a recipe id.
struct RecipeIdWrapper: Identifiable {
    let id: String
}
