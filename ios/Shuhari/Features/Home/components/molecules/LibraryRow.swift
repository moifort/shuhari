import SwiftUI

/// A library row: type icon tile, title (+ "dérivée" tag), a subtitle with the
/// version count and the recipe's best note ("the highest star"), and the mean
/// note as the trailing value. Designed as a List row — the List provides insets,
/// separators and the navigation chevron.
struct LibraryRow: View {
    let title: String
    let type: RecipeType
    let versionCount: Int
    let bestNote: Int?
    let averageNote: Double?
    let isDerived: Bool

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
                HStack(spacing: 6) {
                    if isDerived {
                        StatusTag(kind: .derived)
                    }
                    Text(versionCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let bestNote {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                            Text("\(bestNote)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Meilleure note \(bestNote) sur 5")
                    }
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let averageNote {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(NoteFormat.bare(averageNote))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Status.note(Int(averageNote)))
                    Text("/5")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Note moyenne \(NoteFormat.average(averageNote))")
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
        LibraryRow(title: "Bœuf bourguignon", type: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, isDerived: false)
        LibraryRow(title: "Joues de bœuf confites", type: .plat, versionCount: 1, bestNote: 3, averageNote: 3.0, isDerived: true)
        LibraryRow(title: "Risotto au parmesan", type: .tmx, versionCount: 2, bestNote: nil, averageNote: 4.5, isDerived: false)
    }
}
