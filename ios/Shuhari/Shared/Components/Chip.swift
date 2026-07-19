import SwiftUI

/// The shared neutral chip layout: optional icon + text in a systemFill capsule.
/// Backs `TypeChip` and any future informational chip so they all share one
/// geometry — the version chip on a timeline notch, the type chip on a recipe.
struct Chip: View {
    var icon: String? = nil
    var image: Image? = nil
    let text: String
    /// Tightens the capsule for a chip that trails a row rather than heading a
    /// screen — the version chip closing a version row.
    var compact: Bool = false
    /// Wears the attempt accent instead of the neutral fill — the version the recipe
    /// sheet is showing, among the versions listed behind it.
    var highlighted: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let image {
                image
            } else if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font((compact ? Font.caption2 : .caption).weight(.medium))
        .foregroundStyle(highlighted ? Theme.Status.attempt : .secondary)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 2 : 5)
        .background(highlighted ? Theme.Status.attempt.opacity(0.14) : Color(.systemFill), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: 8) {
        Chip(icon: "birthday.cake", text: "Dessert")
        Chip(icon: nil, text: "Sans icône")
    }
    .padding()
}
