import SwiftUI

/// The pictograms a tag can wear — what stands for it on a library row, where there
/// is no room for its words. A closed set the server names and this enum draws; the
/// case order IS the order the icon picker offers them in.
enum TagIcon: String, CaseIterable, Sendable, Identifiable {
    case thermomix
    case oven
    case microwave
    case barbecue
    case pan
    case freezer
    case quick
    case slow
    case vegetarian
    case fish
    case guests
    case kids
    case festive

    var id: String { rawValue }

    /// What the icon picker calls it — the drawing's name, not a tag: the words of a
    /// tag are the cook's own.
    var label: String {
        switch self {
        case .thermomix: "Thermomix"
        case .oven: "Four"
        case .microwave: "Micro-ondes"
        case .barbecue: "Barbecue"
        case .pan: "Poêle"
        case .freezer: "Congélateur"
        case .quick: "Rapide"
        case .slow: "Longue cuisson"
        case .vegetarian: "Végétarien"
        case .fish: "Poisson"
        case .guests: "Invités"
        case .kids: "Enfants"
        case .festive: "Fête"
        }
    }

    /// Outline forms throughout, like every other badge icon. Thermomix is the custom
    /// symbol of the asset catalog — `Image(systemName:)` only resolves Apple's.
    var iconImage: Image {
        switch self {
        case .thermomix: Image("thermomix")
        case .oven: Image(systemName: "oven")
        case .microwave: Image(systemName: "microwave")
        case .barbecue: Image(systemName: "flame")
        case .pan: Image(systemName: "frying.pan")
        case .freezer: Image(systemName: "snowflake")
        case .quick: Image(systemName: "bolt")
        case .slow: Image(systemName: "hourglass")
        case .vegetarian: Image(systemName: "leaf")
        case .fish: Image(systemName: "fish")
        case .guests: Image(systemName: "person.2")
        case .kids: Image(systemName: "figure.and.child.holdinghands")
        case .festive: Image(systemName: "party.popper")
        }
    }
}

/// A word the cook files a recipe under, in their own words ("Thermomix", "Batch
/// cooking"), with the pictogram that stands for it where there is no room for the
/// word. Worn by the recipe, so it holds for every version of it.
struct Tag: Sendable, Hashable {
    let label: String
    /// Nil on a tag that is read on the recipe sheet only — a library row shows the
    /// icons and nothing else, so a tag without one does not appear there.
    var icon: TagIcon? = nil

    /// The tag as a leaf view draws it.
    var badge: TagBadge { TagBadge(label: label, icon: icon?.iconImage) }
}

/// A tag reduced to what a view draws — its words and its drawing. What the
/// primitive-first leaf views take instead of the domain `Tag`.
struct TagBadge: Identifiable {
    let label: String
    let icon: Image?

    var id: String { label }
}
