import SwiftUI

/// What the library is looking at: everything, one recipe type, or the favourites —
/// which mix every type. The lens picker sits in the home toolbar, one round button
/// per lens; the filter/sort menu keeps working inside whichever lens is on. `.all`
/// is where the notebook opens: the whole library, no facet.
enum LibraryLens: Hashable, Identifiable, Sendable {
    case all
    case type(RecipeType)
    case favorites

    var id: String {
        switch self {
        case .all: "all"
        case .type(let type): type.rawValue
        case .favorites: "favorites"
        }
    }

    var label: String {
        switch self {
        case .all: "Tout"
        case .type(let type): type.label
        case .favorites: "Favoris"
        }
    }

    /// The lens icon, in its outline or filled form — filled marks the lens that is on,
    /// matching how the type icons already read. The heart is the exception: it stays
    /// filled either way, since an outlined heart reads as "not a favourite" rather
    /// than as a lens that is off (the row's own heart already uses that contrast).
    func iconImage(filled: Bool) -> Image {
        switch self {
        case .all: Image(systemName: filled ? "square.grid.2x2.fill" : "square.grid.2x2")
        case .type(let type): type.iconImage(filled: filled)
        case .favorites: Image(systemName: "heart.fill")
        }
    }

    /// The colour the lens wears when it is on: the favourites keep the heart's red,
    /// a type takes the app accent.
    var selectedTint: Color {
        switch self {
        case .all, .type: .accentColor
        case .favorites: Theme.Status.favorite
        }
    }

    /// The recipe type this lens narrows to — nothing for `.all` nor the favourites,
    /// which both mix dishes and Thermomix recipes.
    var recipeType: RecipeType? {
        switch self {
        case .all, .favorites: nil
        case .type(let type): type
        }
    }

    /// The order a lens opens on: favourites read course by course (that is what the
    /// lens is for), everything else reads newest first.
    var defaultSort: RecipeSortOption {
        switch self {
        case .all, .type: .lastModified
        case .favorites: .dishCategory
        }
    }
}
