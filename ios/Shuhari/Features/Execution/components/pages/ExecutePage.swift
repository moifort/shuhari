import SwiftUI

/// Hands-busy execution mode: the version's ingredients and steps shown very
/// large, and a pinned "Terminé — noter cet essai" button.
struct ExecutePage: View {
    let recipeTitle: String
    let version: RecipeVersion
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !version.ingredients.isEmpty {
                    ingredients
                }

                if !version.steps.isEmpty {
                    if !version.ingredients.isEmpty {
                        Divider()
                    }
                    if let tmxItems = TmxStepsList.Item.zipped(steps: version.steps, tmxSteps: version.tmxSteps) {
                        TmxStepsList(items: tmxItems, big: true)
                    } else {
                        StepsList(steps: version.steps, big: true)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(recipeTitle)
        .navigationSubtitle("v\(version.number)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Text("Terminé — noter cet essai")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .accessibilityIdentifier("execute-done-button")
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var ingredients: some View {
        VStack(spacing: 0) {
            ForEach(Array(version.ingredients.enumerated()), id: \.offset) { index, ingredient in
                HStack {
                    Text(ingredient.name)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(ingredient.quantity)
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
                if index != version.ingredients.count - 1 {
                    Divider()
                }
            }
        }
    }
}

#Preview("Plat") {
    NavigationStack {
        ExecutePage(
            recipeTitle: Fixtures.bourguignon.title,
            version: Fixtures.bourguignonV4,
            onDone: {}
        )
    }
}

#Preview("Thermomix") {
    NavigationStack {
        ExecutePage(
            recipeTitle: Fixtures.risotto.title,
            version: Fixtures.risottoV2,
            onDone: {}
        )
    }
}
