import SwiftUI

/// The course a dish belongs to — an aggregate-level identity set once at import
/// (shared across every version), and the axis the library sorts on. Distinct
/// from `RecipeType` (dish vs Thermomix): a Thermomix soup and a plated soup are
/// both `.soup`.
enum DishCategory: String, CaseIterable, Sendable, Identifiable {
    case starter
    case main
    case dessert
    case soup
    case sauce
    case baking

    var id: String { rawValue }

    var label: String {
        switch self {
        case .starter: "Entrée"
        case .main: "Plat"
        case .dessert: "Dessert"
        case .soup: "Soupe"
        case .sauce: "Sauce"
        case .baking: "Boulangerie"
        }
    }

    /// An SF Symbol standing in for the course — used on badges and the import
    /// category picker — outline forms throughout, matching the unfilled `RecipeType`
    /// icon every screen pairs these with. SF Symbols ships no bowl and no bread
    /// glyph, so soup borrows the steaming cup and baking the oven.
    var iconName: String {
        switch self {
        case .starter: "leaf"
        case .main: "fork.knife"
        case .dessert: "birthday.cake"
        case .soup: "cup.and.heat.waves"
        case .sauce: "drop"
        case .baking: "oven"
        }
    }

    var iconImage: Image { Image(systemName: iconName) }
}
