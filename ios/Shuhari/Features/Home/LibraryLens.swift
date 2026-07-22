import SwiftUI

/// What the library is looking at: everything, or the favourites — both mix every
/// recipe type. The lens picker sits in the home toolbar, one round button per
/// lens; the filter/sort menu keeps working inside whichever lens is on. `.all`
/// is where the notebook opens: the whole library, no facet.
enum LibraryLens: Hashable, Identifiable, Sendable {
    case all
    case favorites

    var id: String {
        switch self {
        case .all: "all"
        case .favorites: "favorites"
        }
    }

    var label: String {
        switch self {
        case .all: "Tout"
        case .favorites: "Favoris"
        }
    }

    /// The lens icon, in its outline or filled form — filled marks the lens that is on.
    /// The heart never switches form: its outline reads as "not a favourite" rather
    /// than as a lens that is off, so the tint alone says it is on.
    func iconImage(filled: Bool) -> Image {
        switch self {
        case .all: Image(systemName: filled ? "square.grid.2x2.fill" : "square.grid.2x2")
        case .favorites: Image(systemName: "heart.fill")
        }
    }

    /// The colour the lens wears when it is on: the favourites keep the heart's red.
    var selectedTint: Color {
        switch self {
        case .all: .accentColor
        case .favorites: Theme.Status.favorite
        }
    }

    /// The order a lens opens on: favourites read course by course (that is what the
    /// lens is for), everything else reads newest first.
    var defaultSort: RecipeSortOption {
        switch self {
        case .all: .lastModified
        case .favorites: .dishCategory
        }
    }
}
