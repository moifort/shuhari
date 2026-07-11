import SwiftUI

/// An uppercase section header with an optional count, matching the maquette's
/// `.sect-title` typography. `tint` colours the label (e.g. amber for "À tester").
struct SectionHeader: View {
    let title: String
    var count: Int? = nil
    var tint: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(tint ?? .secondary)
            if let count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

/// The rounded "card" surface used to group rows or hold a version's content.
struct CarnetCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func carnetCard() -> some View { modifier(CarnetCard()) }
}
