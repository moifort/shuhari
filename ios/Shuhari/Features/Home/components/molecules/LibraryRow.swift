import SwiftUI

/// A library row: the course icon, the title, a subtitle with the version count, and
/// the recipe's best rating ("the highest star" across every version it ever cooked)
/// as trailing stars. The icon and the stars sit on the title's line. Designed as a
/// List row — the List provides insets and separators.
struct LibraryRow: View {
    let title: String
    let category: DishCategory
    let versionCount: Int
    let bestRating: Int?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            category.iconImage
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityLabel(category.label)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(versionCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let bestRating {
                RatingStars(rating: Double(bestRating))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel("Meilleure note \(bestRating) sur 5")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var versionCountText: String {
        "\(versionCount) version\(versionCount > 1 ? "s" : "")"
    }
}

#Preview {
    List {
        LibraryRow(title: "Bœuf bourguignon", category: .main, versionCount: 4, bestRating: 5)
        LibraryRow(title: "Tarte au citron meringuée", category: .dessert, versionCount: 1, bestRating: 3)
        LibraryRow(title: "Velouté de courge", category: .soup, versionCount: 2, bestRating: nil)
    }
}
