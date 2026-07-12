import SwiftUI

/// A library row: type icon, title (+ "dérivée" badge), and a subtitle line that
/// reads "vN courante · X,X/10 moy. · vM à tester". Designed as a List row —
/// the List provides insets, separators and the navigation chevron.
struct LibraryRow: View {
    let title: String
    let type: RecipeType
    let currentVersionNumber: Int?
    let averageNote: Double?
    let toTestNumber: Int?
    let isDerived: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isDerived {
                        Label("dérivée", systemImage: "link")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let currentVersionNumber { parts.append("v\(currentVersionNumber) courante") }
        if let averageNote { parts.append(NoteFormat.averageWithSuffix(averageNote)) }
        if let toTestNumber { parts.append("v\(toTestNumber) à tester") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        LibraryRow(title: "Espresso — Brésil", type: .cafe, currentVersionNumber: 3, averageNote: 7.5, toTestNumber: 4, isDerived: false)
        LibraryRow(title: "Negroni blanc", type: .cocktail, currentVersionNumber: 1, averageNote: 6.0, toTestNumber: nil, isDerived: true)
    }
}
