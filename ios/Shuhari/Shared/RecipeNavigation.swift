import Foundation

/// Push destinations inside the notebook `NavigationStack`.
enum RecipeRoute: Hashable {
    case recipe(id: String)
    case attempt(recipeId: String, versionNumber: Int)
}

/// A request to run the execution flow on a given version, presented as a sheet from
/// the recipe's record CTA.
struct ExecutionRequest: Identifiable, Hashable {
    let recipeId: String
    let versionNumber: Int

    var id: String { "\(recipeId)#\(versionNumber)" }
}

/// Identifiable wrapper to drive a `.sheet(item:)` from a recipe id.
struct RecipeIdWrapper: Identifiable {
    let id: String
}

/// A freshly imported recipe handed from the import flow to its category tab,
/// which then navigates to the new recipe sheet. The `type` picks the destination tab.
struct ImportedRecipe: Equatable {
    let id: String
    let type: RecipeType
}
