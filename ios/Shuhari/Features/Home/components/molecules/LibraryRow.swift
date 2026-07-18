import SwiftUI

/// A library row: type icon tile, title, a subtitle with the version count, and
/// the recipe's best note ("the highest star" across every version it ever cooked)
/// as the trailing value. Designed as a List row — the List provides insets,
/// separators and the navigation chevron.
struct LibraryRow: View {
    let title: String
    let type: RecipeType
    let versionCount: Int
    let bestNote: Int?

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

            if let bestNote {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(bestNote)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Status.note(bestNote))
                    Text("/5")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Meilleure note \(bestNote) sur 5")
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
        LibraryRow(title: "Bœuf bourguignon", type: .plat, versionCount: 4, bestNote: 5)
        LibraryRow(title: "Joues de bœuf confites", type: .plat, versionCount: 1, bestNote: 3)
        LibraryRow(title: "Risotto au parmesan", type: .tmx, versionCount: 2, bestNote: nil)
    }
}
