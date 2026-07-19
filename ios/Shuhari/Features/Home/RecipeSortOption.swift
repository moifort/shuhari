import Foundation

/// The two ways the library can be ordered, exposed through the sort menu. Pure
/// design tokens (label + icon); the mapping to the GraphQL `RecipeSort`/`SortOrder`
/// pair lives in `LibraryAPI` so this stays decoupled from the generated types.
enum RecipeSortOption: String, CaseIterable, Identifiable, Sendable {
    /// Most recently modified first (`UPDATED_AT` / `DESC`) — the default.
    case lastModified
    /// Fixed dish-course order (`CATEGORY`) — starter → main → dessert → soup →
    /// sauce → baking, most recently modified first within a course.
    case dishCategory

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastModified: "Dernière modification"
        case .dishCategory: "Type de plat"
        }
    }

    var icon: String {
        switch self {
        case .lastModified: "clock"
        case .dishCategory: "fork.knife"
        }
    }
}
