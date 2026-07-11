import SwiftUI

/// A library row: type icon, title (+ "dérivée" badge), and a subtitle line that
/// reads "vN courante · X,X/10 moy. · vM à tester".
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
                .foregroundStyle(type.color)
                .frame(width: 34, height: 34)
                .background(type.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if let currentVersionNumber { parts.append("v\(currentVersionNumber) courante") }
        if let averageNote { parts.append(String(format: "%.1f/10 moy.", averageNote).replacingOccurrences(of: ".", with: ",")) }
        if let toTestNumber { parts.append("v\(toTestNumber) à tester") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    VStack(spacing: 0) {
        LibraryRow(title: "Espresso — Brésil", type: .cafe, currentVersionNumber: 3, averageNote: 7.5, toTestNumber: 4, isDerived: false)
        Divider()
        LibraryRow(title: "Negroni blanc", type: .cocktail, currentVersionNumber: 1, averageNote: 6.0, toTestNumber: nil, isDerived: true)
    }
    .padding()
}
