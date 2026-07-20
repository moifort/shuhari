import SwiftUI

/// A library row: the course icon, the title, a subtitle with the version count closed
/// by the recipe type as an icon-only chip, the recipe's best rating ("the
/// highest star" across every version it ever cooked) as trailing stars, and the
/// favourite heart closing the line. The icon, the stars and the heart sit on the
/// title's line. Designed as a List row — the List provides insets and separators.
struct LibraryRow: View {
    let title: String
    let type: RecipeType
    let category: DishCategory
    let versionCount: Int
    /// How many of those versions are waiting to be cooked — `0` drops the count from
    /// the subtitle rather than writing "0 essai".
    var toTestCount: Int = 0
    let bestRating: Int?
    var favorite: Bool = false

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
                HStack(spacing: Theme.Spacing.xs) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Chip(image: type.iconImage(filled: false), compact: true)
                        .accessibilityLabel(type.label)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let bestRating {
                RatingStars(rating: Double(bestRating))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel("Meilleure note \(bestRating) sur 5")
            }

            if favorite {
                Image(systemName: "heart.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.Status.favorite)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel("Favori")
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "4 versions · 2 essais" — the cooks the recipe still owes, dropped entirely
    /// when it owes none (nothing to say beyond its versions).
    private var subtitle: String {
        let versions = "\(versionCount) version\(versionCount > 1 ? "s" : "")"
        guard toTestCount > 0 else { return versions }
        return "\(versions) · \(toTestCount) essai\(toTestCount > 1 ? "s" : "")"
    }
}

#Preview {
    List {
        LibraryRow(title: "Bœuf bourguignon", type: .dish, category: .main, versionCount: 4, toTestCount: 1, bestRating: 5, favorite: true)
        LibraryRow(title: "Tarte au citron meringuée", type: .thermomix, category: .dessert, versionCount: 1, toTestCount: 1, bestRating: 3)
        LibraryRow(title: "Velouté de courge", type: .thermomix, category: .soup, versionCount: 2, toTestCount: 0, bestRating: nil, favorite: true)
    }
}
