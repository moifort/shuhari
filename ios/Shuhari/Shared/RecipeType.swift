import SwiftUI

/// The four experiment domains, with their design tokens (icon + label)
/// and the business rule that drives the app copy: coffee and cocktails change
/// one variable per iteration, dishes and Thermomix recipes several.
enum RecipeType: String, CaseIterable, Sendable, Identifiable {
    case cafe
    case cocktail
    case plat
    case tmx

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cafe: "Café"
        case .cocktail: "Cocktail"
        case .plat: "Plat"
        case .tmx: "Thermomix"
        }
    }

    /// The type's icon as an `Image`. Coffee is Apple's `mug.fill` SF Symbol; the
    /// other three are custom symbols in the asset catalog (a martini glass for
    /// cocktails, a chef's toque for dishes, the Thermomix mark) — referenced by
    /// asset name, since `Image(systemName:)` only resolves Apple's SF Symbols.
    /// Custom symbols scale with the font and tint just like SF Symbols.
    var iconImage: Image {
        switch self {
        case .cafe: Image(systemName: "mug.fill")
        case .cocktail: Image("cocktail")
        case .plat: Image("toque")
        case .tmx: Image("thermomix")
        }
    }

    /// True when this type is constrained to a single variable per iteration.
    var oneVariableRule: Bool {
        self == .cafe || self == .cocktail
    }

    var ruleText: String {
        oneVariableRule
            ? "Une seule variable par itération"
            : "Plusieurs variables possibles"
    }
}
