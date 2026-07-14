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

    /// SF Symbol name. Thermomix has no SF Symbol; `iconImage` maps it to the
    /// custom symbol, and this keeps a valid fallback for any raw `systemName:` use.
    var icon: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .cocktail: "wineglass.fill"
        case .plat: "frying.pan.fill"
        case .tmx: "fan.fill"
        }
    }

    /// The type's icon as an `Image` — a custom symbol for Thermomix (referenced by
    /// asset name, since `Image(systemName:)` only resolves Apple's SF Symbols),
    /// an SF Symbol otherwise. Custom symbols scale with the font and tint just
    /// like SF Symbols. Prefer this over `icon` for display.
    var iconImage: Image {
        switch self {
        case .tmx: Image("thermomix")
        default: Image(systemName: icon)
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
