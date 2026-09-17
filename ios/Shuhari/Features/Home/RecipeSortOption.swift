import Foundation

/// The ways a library can be ordered, exposed through the sort menu. Pure design
/// tokens (label + icon); the mapping to the GraphQL `RecipeSort`/`SortOrder` pair
/// lives in `LibraryAPI` so this stays decoupled from the generated types. Which
/// options a tab offers is the tab's call — `cooking` and `coffee` below.
enum RecipeSortOption: String, CaseIterable, Identifiable, Sendable {
    /// Fixed dish-course order (`CATEGORY`) — starter → main → dessert → soup →
    /// sauce → baking — what the notebook opens on. Within a course: the favourites
    /// first, then by best rating, the recipes never cooked last.
    case dishCategory
    /// Fixed brewing order (`METHOD`) — espresso → … → cold brew — what the coffee
    /// tab opens on. Same order within a method as within a course.
    case brewMethod
    /// Most recently modified first (`UPDATED_AT` / `DESC`) — "what did I cook last
    /// week", the one question the filed order does not answer.
    case lastModified

    var id: String { rawValue }

    /// What the cooking notebook offers: a coffee is never sorted by dish course.
    static let cooking: [RecipeSortOption] = [.dishCategory, .lastModified]
    /// What the coffee tab offers.
    static let coffee: [RecipeSortOption] = [.brewMethod, .lastModified]

    var label: String {
        switch self {
        case .lastModified: "Dernière modification"
        case .dishCategory: "Type de plat"
        case .brewMethod: "Méthode"
        }
    }

    var icon: String {
        switch self {
        case .lastModified: "clock"
        case .dishCategory: "fork.knife"
        case .brewMethod: "cup.and.saucer"
        }
    }
}
