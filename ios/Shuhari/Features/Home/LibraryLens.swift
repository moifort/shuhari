import SwiftUI

/// What the library is looking at: one recipe type, or the favourites — which mix
/// every type. The lens picker sits in the home toolbar, one round button per lens;
/// the filter/sort menu keeps working inside whichever lens is on.
enum LibraryLens: Hashable, Identifiable, Sendable {
    case type(RecipeType)
    case favorites

    var id: String {
        switch self {
        case .type(let type): type.rawValue
        case .favorites: "favorites"
        }
    }

    var label: String {
        switch self {
        case .type(let type): type.label
        case .favorites: "Favoris"
        }
    }

    /// The lens icon, in its outline or filled form — filled marks the lens that is on,
    /// matching how the type icons already read.
    func iconImage(filled: Bool) -> Image {
        switch self {
        case .type(let type): type.iconImage(filled: filled)
        case .favorites: Image(systemName: filled ? "heart.fill" : "heart")
        }
    }

    /// The colour the lens wears when it is on: the favourites keep the heart's red,
    /// a type takes the app accent.
    var selectedTint: Color {
        switch self {
        case .type: .accentColor
        case .favorites: Theme.Status.favorite
        }
    }

    /// The recipe type this lens narrows to — nothing for the favourites, which mix
    /// dishes and Thermomix recipes.
    var recipeType: RecipeType? {
        switch self {
        case .type(let type): type
        case .favorites: nil
        }
    }

    /// The order a lens opens on: favourites read course by course (that is what the
    /// lens is for), a type reads newest first.
    var defaultSort: RecipeSortOption {
        switch self {
        case .type: .lastModified
        case .favorites: .dishCategory
        }
    }
}
