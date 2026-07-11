import SwiftUI

/// Reminder of the variable budget for a recipe type — the scientific constraint
/// surfaced on the proposal screen ("Une seule variable" for coffee/cocktail).
struct RuleChip: View {
    let type: RecipeType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.oneVariableRule ? "1.circle.fill" : "square.stack.3d.up.fill")
            Text(type.ruleText)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(type.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(type.color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        RuleChip(type: .cafe)
        RuleChip(type: .plat)
    }
    .padding()
}
