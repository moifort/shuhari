import SwiftUI

/// A journal / recent-activity row: coloured note badge, recipe name + version
/// chip, and a truncated remarks excerpt with the date.
struct TrialRow: View {
    let recipeTitle: String?
    let versionNumber: Int
    let note: Int
    let remarks: String
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            NoteBadge(note: note)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(recipeTitle ?? formattedDate)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("v\(versionNumber)")
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
                }
                Text(recipeTitle == nil ? remarks : "\(formattedDate) · \(remarks)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var formattedDate: String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

#Preview {
    TrialRow(
        recipeTitle: "Espresso — Brésil",
        versionNumber: 3,
        note: 8,
        remarks: "Équilibré, chocolat noir en finale.",
        date: Date()
    )
    .padding()
}
