import Foundation

/// Push destinations inside the Carnet `NavigationStack`.
enum RecipeRoute: Hashable {
    case recipe(id: String)
    case history(id: String)
    case trial(id: String)
}

/// A request to run the execution flow (presented as a full-screen cover).
/// `startAtCapture` skips the step-by-step `ExecutePage` and opens the trial
/// capture directly — the fiche already shows the recipe, so re-displaying it
/// would be redundant.
struct ExecutionRequest: Identifiable, Hashable {
    let recipeId: String
    let versionNumber: Int
    var startAtCapture: Bool = false

    var id: String { "\(recipeId)#\(versionNumber)#\(startAtCapture)" }
}

/// Identifiable wrapper to drive a `.sheet(item:)` from a recipe id.
struct RecipeIdWrapper: Identifiable {
    let id: String
}

/// A freshly imported recipe handed from the import flow to its category tab,
/// which then navigates to the new fiche. The `type` picks the destination tab.
struct ImportedRecipe: Equatable {
    let id: String
    let type: RecipeType
}
