import SwiftUI

/// A library row: type icon tile, title, a subtitle with the version count, and
/// the recipe's best rating ("the highest star" across every version it ever cooked)
/// as the trailing value. Designed as a List row — the List provides insets,
/// separators and the navigation chevron.
struct LibraryRow: View {
    let title: String
    let type: RecipeType
    let versionCount: Int
    let bestRating: Int?

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 34

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            type.iconImage(filled: false)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: tileSize, height: tileSize)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: Theme.Radius.control))

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
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(bestRating)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Status.rating(bestRating))
                    Text("/5")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
        LibraryRow(title: "Bœuf bourguignon", type: .dish, versionCount: 4, bestRating: 5)
        LibraryRow(title: "Joues de bœuf confites", type: .dish, versionCount: 1, bestRating: 3)
        LibraryRow(title: "Risotto au parmesan", type: .thermomix, versionCount: 2, bestRating: nil)
    }
}
