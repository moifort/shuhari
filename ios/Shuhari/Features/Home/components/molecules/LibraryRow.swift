import SwiftUI

/// A library row: type icon tile, title (+ "dérivée" tag), a lineage subtitle
/// ("vN courante · vM à tester") and the mean note as the trailing value.
/// Designed as a List row — the List provides insets, separators and the
/// navigation chevron.
struct LibraryRow: View {
    let title: String
    let type: RecipeType
    let currentVersionNumber: Int?
    let averageNote: Double?
    let toTestNumber: Int?
    let isDerived: Bool

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 34

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            type.iconImage
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
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let averageNote {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(NoteFormat.bare(averageNote))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Status.note(Int(averageNote)))
                    Text("/10")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Note moyenne \(NoteFormat.average(averageNote))")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let currentVersionNumber { parts.append("v\(currentVersionNumber) courante") }
        if let toTestNumber { parts.append("v\(toTestNumber) à tester") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        LibraryRow(title: "Espresso — Brésil", type: .cafe, currentVersionNumber: 3, averageNote: 7.5, toTestNumber: 4, isDerived: false)
        LibraryRow(title: "Negroni blanc", type: .cocktail, currentVersionNumber: 1, averageNote: 6.0, toTestNumber: nil, isDerived: true)
        LibraryRow(title: "Risotto au parmesan", type: .tmx, currentVersionNumber: 2, averageNote: 8.5, toTestNumber: nil, isDerived: false)
    }
}
