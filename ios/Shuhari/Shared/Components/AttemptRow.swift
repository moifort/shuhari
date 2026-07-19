import SwiftUI

/// A journal / recent-activity row: coloured rating badge, recipe name + version,
/// and a truncated remarks excerpt with the date. Designed as a List row.
struct AttemptRow: View {
    let recipeTitle: String?
    let versionNumber: Int
    let rating: Int
    let remarks: String
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            RatingBadge(rating: rating)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(recipeTitle ?? formattedDate)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("v\(versionNumber)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(recipeTitle == nil ? remarks : "\(formattedDate) · \(remarks)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var formattedDate: String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

#Preview {
    List {
        AttemptRow(
            recipeTitle: "Espresso — Brésil",
            versionNumber: 3,
            rating: 4,
            remarks: "Équilibré, chocolat noir en finale.",
            date: Date()
        )
    }
}
