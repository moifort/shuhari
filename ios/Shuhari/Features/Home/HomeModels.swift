import Foundation

/// A recipe with a pending version awaiting a trial — rendered as a "À tester" banner.
struct HomeTestItem: Identifiable, Sendable {
    let id: String
    let title: String
    let type: RecipeType
    let versionNumber: Int
    let change: String?
    let why: String?
}

/// A library row: current reference version, its mean note, and pending-version badge.
struct LibraryRecipe: Identifiable, Sendable {
    let id: String
    let title: String
    let type: RecipeType
    let currentVersionNumber: Int?
    let averageNote: Double?
    let toTestNumber: Int?
    let isDerived: Bool
}

/// The read model behind the home screen.
struct HomeData: Sendable {
    let toTest: [HomeTestItem]
    let library: [LibraryRecipe]
    let recentTrials: [Trial]

    /// The library groups the recipes by type; sections keep the design order.
    func recipes(of type: RecipeType) -> [LibraryRecipe] {
        library.filter { $0.type == type }
    }

    func title(forRecipe id: String) -> String {
        library.first { $0.id == id }?.title ?? "Recette"
    }
}
