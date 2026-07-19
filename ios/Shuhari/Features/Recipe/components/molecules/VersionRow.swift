import SwiftUI

/// One version in the history sheet: the change it carries as the title, then —
/// pushed to the right — the rating its attempt earned as stars and the version
/// number as a chip closing the row. The chip wears the attempt accent on the
/// version the recipe sheet behind is showing.
struct VersionRow: View {
    let number: Int
    let change: String?
    let rating: Int?
    /// The version the recipe sheet behind is showing — the only row whose chip
    /// wears the attempt accent.
    let isFocus: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(change?.isEmpty == false ? change! : "Version d’origine")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Spacer(minLength: Theme.Spacing.s)
            if let rating {
                RatingStars(rating: Double(rating))
                    .accessibilityLabel("Notée \(rating) sur 5")
            }
            Chip(text: "v\(number)", compact: true, highlighted: isFocus)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        VersionRow(number: 4, change: "Température 93 → 92 °C", rating: nil, isFocus: true)
        VersionRow(number: 3, change: "Mouture plus fine", rating: 4, isFocus: false)
        VersionRow(number: 1, change: nil, rating: 3, isFocus: false)
    }
}
