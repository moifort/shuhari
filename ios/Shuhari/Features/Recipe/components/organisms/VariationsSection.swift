import SwiftUI

/// Recipes derived from this one (linked variations, each its own lineage).
struct VariationsSection: View {
    let variations: [RecipeRef]

    var body: some View {
        if !variations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Variations liées")
                VStack(spacing: 0) {
                    ForEach(Array(variations.enumerated()), id: \.element.id) { index, ref in
                        NavigationLink(value: RecipeRoute.recipe(id: ref.id)) {
                            LibraryRow(
                                title: ref.title,
                                type: ref.type,
                                currentVersionNumber: ref.currentVersionNumber,
                                averageNote: ref.averageNote,
                                toTestNumber: nil,
                                isDerived: true
                            )
                        }
                        .buttonStyle(.plain)
                        if index < variations.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .carnetCard()
            }
        }
    }
}
