import SwiftUI

/// The four experiment domains, with their design tokens (colour + icon + label)
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
        case .tmx: "microwave.fill"
        }
    }

    /// The accent colour, adapting to light/dark exactly like the maquette palette.
    var color: Color {
        switch self {
        case .cafe: Self.dynamic(light: (0.54, 0.35, 0.18), dark: (0.78, 0.56, 0.35))
        case .cocktail: Self.dynamic(light: (0.66, 0.24, 0.21), dark: (0.88, 0.48, 0.45))
        case .plat: Self.dynamic(light: (0.36, 0.48, 0.23), dark: (0.61, 0.73, 0.42))
        case .tmx: Self.dynamic(light: (0.18, 0.48, 0.52), dark: (0.44, 0.72, 0.76))
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

    private static func dynamic(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}
