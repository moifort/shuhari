import SwiftUI

/// The course a dish belongs to — an aggregate-level identity set once at import
/// (shared across every version), and the axis the library sorts on. Distinct
/// from `RecipeType` (plat vs Thermomix): a Thermomix soup and a plated soup are
/// both `.soupe`.
enum DishCategory: String, CaseIterable, Sendable, Identifiable {
    case entree
    case plat
    case dessert
    case soupe
    case sauce
    case boulangerie

    var id: String { rawValue }

    var label: String {
        switch self {
        case .entree: "Entrée"
        case .plat: "Plat"
        case .dessert: "Dessert"
        case .soupe: "Soupe"
        case .sauce: "Sauce"
        case .boulangerie: "Boulangerie"
        }
    }

    /// An SF Symbol standing in for the course — used on badges and the import
    /// category picker — outline forms throughout, matching the unfilled `RecipeType`
    /// icon every screen pairs these with. SF Symbols ships no bowl and no bread
    /// glyph, so soup borrows the steaming cup and boulangerie the oven.
    var iconName: String {
        switch self {
        case .entree: "leaf"
        case .plat: "fork.knife"
        case .dessert: "birthday.cake"
        case .soupe: "cup.and.heat.waves"
        case .sauce: "drop"
        case .boulangerie: "oven"
        }
    }

    var iconImage: Image { Image(systemName: iconName) }
}
