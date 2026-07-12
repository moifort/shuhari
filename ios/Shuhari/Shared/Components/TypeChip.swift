import SwiftUI

/// A small type indicator: the recipe type's icon + label, monochrome.
struct TypeChip: View {
    let type: RecipeType

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: type.icon)
            Text(type.label)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemFill), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(RecipeType.allCases) { TypeChip(type: $0) }
    }
    .padding()
}
