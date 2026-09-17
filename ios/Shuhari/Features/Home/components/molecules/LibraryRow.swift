import SwiftUI

/// A library row: the filing icon, the title, a subtitle with the version count
/// closed by the recipe's tags as icon-only chips, and ONE trailing mark on the
/// title's line: the favourite heart, or else the recipe's best rating ("the
/// highest star" across every version it ever cooked) as stars. The heart replaces
/// the stars rather than joining them — "I would make this again" already says what
/// a rating would, and it is what the library ranks a favourite on. Designed as a List row — the List provides insets and separators.
///
/// The leading icon is what the recipe is filed by: its course for a dish, its
/// brew method for a coffee — every coffee is a `drink`, so the course icon would
/// say the same thing on every row of the coffee tab.
///
/// A row has no room for a tag's words, so it shows the tags that wear an icon and
/// nothing of the others — those are read on the recipe sheet.
struct LibraryRow: View {
    let title: String
    let category: DishCategory
    /// Set on a coffee and on nothing else.
    var method: BrewMethod? = nil
    var tags: [TagBadge] = []
    let versionCount: Int
    /// How many of those versions are waiting to be cooked — `0` drops the count from
    /// the subtitle rather than writing "0 essai".
    var toTestCount: Int = 0
    let bestRating: Int?
    var favorite: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            (method?.iconImage ?? category.iconImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityLabel(method?.label ?? category.label)

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
                    ForEach(tags) { tag in
                        if let icon = tag.icon {
                            Chip(image: icon, compact: true)
                                .accessibilityLabel(tag.label)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if favorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Theme.Status.favorite)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel("Favori")
            } else if let bestRating {
                RatingStars(rating: Double(bestRating), font: .caption2)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel("Meilleure note \(bestRating) sur 5")
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
        LibraryRow(title: "Bœuf bourguignon", category: .main, tags: [Tag(label: "Invités", icon: .guests).badge, Tag(label: "Dimanche").badge], versionCount: 4, toTestCount: 1, bestRating: 5, favorite: true)
        LibraryRow(title: "Tarte au citron meringuée", category: .dessert, tags: [Tag(label: "Thermomix", icon: .thermomix).badge], versionCount: 1, toTestCount: 1, bestRating: 3)
        LibraryRow(title: "Velouté de courge", category: .soup, tags: [Tag(label: "Thermomix", icon: .thermomix).badge, Tag(label: "Congélation", icon: .freezer).badge], versionCount: 2, toTestCount: 0, bestRating: nil, favorite: true)
        LibraryRow(title: "V60 Éthiopie Guji", category: .drink, method: .v60, versionCount: 2, toTestCount: 0, bestRating: 5, favorite: true)
        LibraryRow(title: "Bialetti 3 tasses", category: .drink, method: .moka, versionCount: 1, toTestCount: 0, bestRating: 3)
    }
}
