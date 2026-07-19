import SwiftUI

/// The two culinary experiment domains, with their design tokens (icon + label):
/// a cooked dish or a Thermomix recipe. (Café and cocktail were retired — the app
/// is cooking-only.)
enum RecipeType: String, CaseIterable, Sendable, Identifiable {
    case dish
    case thermomix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dish: "Plat"
        case .thermomix: "Thermomix"
        }
    }

    /// A compact label for header badges, where the full "Thermomix" would wrap
    /// onto several lines.
    var shortLabel: String {
        switch self {
        case .dish: "Plat"
        case .thermomix: "TMX"
        }
    }

    /// The type's icon, in its outline or filled form. Dishes (`frying.pan`) are
    /// Apple SF Symbols; Thermomix uses a custom symbol in the asset catalog —
    /// referenced by asset name, since `Image(systemName:)` only resolves Apple's
    /// SF Symbols. Custom symbols pick their variant by asset name because
    /// `.symbolVariant` only rewrites system symbol names. Custom symbols scale
    /// with the font and tint just like SF Symbols.
    func iconImage(filled: Bool) -> Image {
        switch self {
        case .dish: Image(systemName: filled ? "frying.pan.fill" : "frying.pan")
        case .thermomix: Image(filled ? "thermomix.fill" : "thermomix")
        }
    }

    /// The type's canonical icon — the filled form, used where no selection state
    /// applies (chips, badges, rows).
    var iconImage: Image { iconImage(filled: true) }
}
