import SwiftUI

/// A small type indicator: the recipe type's icon + label, monochrome.
struct TypeChip: View {
    let type: RecipeType

    var body: some View {
        Chip(icon: type.icon, text: type.label)
            .accessibilityLabel("Type \(type.label)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(RecipeType.allCases) { TypeChip(type: $0) }
    }
    .padding()
}
