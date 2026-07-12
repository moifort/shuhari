import SwiftUI

/// Reminder of the variable budget for a recipe type — the scientific constraint
/// surfaced on the proposal screen ("Une seule variable" for coffee/cocktail).
struct RuleChip: View {
    let type: RecipeType

    var body: some View {
        Label(type.ruleText, systemImage: type.oneVariableRule ? "1.circle" : "square.stack.3d.up")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        RuleChip(type: .cafe)
        RuleChip(type: .plat)
    }
    .padding()
}
