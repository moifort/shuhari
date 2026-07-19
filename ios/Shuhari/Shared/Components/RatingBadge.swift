import SwiftUI

/// An attempt rating (1–5) shown as a coloured pill. Thresholds mirror the maquette:
/// ≥ 4 high (green), 3 medium (amber), ≤ 2 low (red).
struct RatingBadge: View {
    let rating: Int

    var body: some View {
        Text("\(rating)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Theme.Status.rating(rating), in: Circle())
            .accessibilityLabel("Note \(rating) sur 5")
    }
}

#Preview {
    HStack(spacing: 12) {
        RatingBadge(rating: 5)
        RatingBadge(rating: 3)
        RatingBadge(rating: 1)
    }
    .padding()
}
