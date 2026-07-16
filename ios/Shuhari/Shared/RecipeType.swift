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

    /// The type's icon, in its outline or filled form. Coffee (an espresso cup,
    /// `cup.and.saucer`) and dishes (`frying.pan`) are Apple SF Symbols; cocktails
    /// (a martini glass) and Thermomix use custom symbols in the asset catalog —
    /// referenced by asset name, since `Image(systemName:)` only resolves Apple's
    /// SF Symbols. Custom symbols pick their variant by asset name because
    /// `.symbolVariant` only rewrites system symbol names; the cocktail glyph
    /// ships in a single form. Custom symbols scale with the font and tint just
    /// like SF Symbols.
    func iconImage(filled: Bool) -> Image {
        switch self {
        case .cafe: Image(systemName: filled ? "cup.and.saucer.fill" : "cup.and.saucer")
        case .cocktail: Image("cocktail")
        case .plat: Image(systemName: filled ? "frying.pan.fill" : "frying.pan")
        case .tmx: Image(filled ? "thermomix.fill" : "thermomix")
        }
    }

    /// The type's canonical icon — the filled form, used where no selection state
    /// applies (chips, badges, rows).
    var iconImage: Image { iconImage(filled: true) }

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
