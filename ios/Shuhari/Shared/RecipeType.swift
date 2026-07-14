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

    var icon: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .cocktail: "wineglass.fill"
        case .plat: "frying.pan.fill"
        case .tmx: "fan.fill"
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
