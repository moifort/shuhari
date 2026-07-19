import SwiftUI

/// One version in the history sheet: the change it carries as the title, then —
/// pushed to the right — the rating its attempt earned as stars and the version
/// number as a chip closing the row. The chip wears the attempt accent on the
/// version the recipe sheet behind is showing.
struct VersionRow: View {
    let number: Int
    let change: String?
    let originDetail: String?
    let rating: Int?
    let tried: Bool
    /// The version the recipe sheet behind is showing — the only row whose chip
    /// wears the attempt accent.
    let isFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Where the version comes from, or the state of its attempt when it earned no
    /// rating — the stars say the rest.
    private var subtitle: String? {
        if let originDetail, !originDetail.isEmpty { return originDetail }
        if rating == nil { return tried ? "Essayée" : "Pas encore essayée" }
        return nil
    }
}

#Preview {
    List {
        VersionRow(number: 4, change: "Température 93 → 92 °C", originDetail: "Extraction trop chaude.", rating: nil, tried: false, isFocus: true)
        VersionRow(number: 3, change: "Mouture plus fine", originDetail: nil, rating: 4, tried: true, isFocus: false)
        VersionRow(number: 1, change: nil, originDetail: nil, rating: 3, tried: true, isFocus: false)
    }
}
