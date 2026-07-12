import SwiftUI

/// Hands-busy execution mode: very large parameters and steps, and a pinned
/// "Terminé — noter cet essai" button. In replay mode the real parameters of a
/// past trial are reinjected.
struct ExecutePage: View {
    let recipeTitle: String
    let version: RecipeVersion
    /// When set, the params actually used in the replayed trial (keyed by name).
    let replayParams: [Param]?
    let replayDate: Date?
    let onDone: () -> Void

    private var displayParams: [ParamsGrid.Item] {
        version.params.map { param in
            let value = replayParams?.first { $0.key == param.key }?.value ?? param.value
            let isReplayed = replayParams?.contains { $0.key == param.key } ?? false
            return ParamsGrid.Item(
                key: param.key,
                value: value,
                highlighted: isReplayed || version.changedKeys.contains(param.key)
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let replayDate {
                    Label(
                        "Rejoue exactement l’essai du \(replayDate.formatted(.dateTime.day().month(.abbreviated))) — paramètres réels appliqués.",
                        systemImage: "arrow.trianglehead.counterclockwise"
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.Status.current)
                }

                ParamsGrid(items: displayParams, big: true)

                if !version.steps.isEmpty {
                    Divider()
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
}

#Preview("Café") {
    NavigationStack {
        ExecutePage(
            recipeTitle: Fixtures.espresso.title,
            version: Fixtures.espressoV4,
            replayParams: nil,
            replayDate: nil,
            onDone: {}
        )
    }
}

#Preview("Thermomix") {
    NavigationStack {
        ExecutePage(
            recipeTitle: Fixtures.risotto.title,
            version: Fixtures.risottoV2,
            replayParams: nil,
            replayDate: nil,
            onDone: {}
        )
    }
}
