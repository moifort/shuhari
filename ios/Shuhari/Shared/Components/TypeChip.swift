import SwiftUI

/// A small type indicator: the recipe type's icon + label in its accent colour.
struct TypeChip: View {
    let type: RecipeType

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: type.icon)
            Text(type.label)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(type.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(type.color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(RecipeType.allCases) { TypeChip(type: $0) }
    }
    .padding()
}
