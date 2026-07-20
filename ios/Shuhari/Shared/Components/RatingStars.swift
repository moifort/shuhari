import SwiftUI

/// Read-only 5-star display of a rating on the native 1–5 scale.
/// The mirror of the `StarRating` input, for showing a rating already given.
struct RatingStars: View {
    let rating: Double
    /// How big the stars read — dropped to `.caption2` where the rating closes a list
    /// row, so the five of them stay a discreet trailing mark next to the heart.
    var font: Font = .footnote

    private var filled: Int { Int(rating.rounded()) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= filled ? "star.fill" : "star")
                    .foregroundStyle(star <= filled ? Color.yellow : Color(.tertiaryLabel))
            }
        }
        .font(font)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Note \(RatingFormat.average(rating))")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        RatingStars(rating: 5)
        RatingStars(rating: 3.5)
        RatingStars(rating: 2)
        RatingStars(rating: 1)
    }
    .padding()
}
