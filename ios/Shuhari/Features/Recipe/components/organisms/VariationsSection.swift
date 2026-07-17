import SwiftUI

/// Recipes derived from this one (linked variations, each its own lineage).
/// Composes as a `Section` directly inside a `List`.
struct VariationsSection: View {
    let variations: [RecipeRef]

    var body: some View {
        if !variations.isEmpty {
            Section("Variations liées") {
                ForEach(variations) { ref in
                    NavigationLink(value: RecipeRoute.recipe(id: ref.id)) {
                        LibraryRow(
                            title: ref.title,
                            type: ref.type,
                            versionCount: ref.versionCount,
                            bestNote: ref.bestNote,
                            averageNote: ref.averageNote,
                            isDerived: true
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            VariationsSection(variations: Fixtures.bourguignon.variations)
        }
    }
}
