import SwiftUI

/// Hands-busy execution mode: very large parameters and steps, and a sticky
/// "Terminé — noter cet essai" button. In replay mode the real parameters of a
/// past trial are reinjected.
struct ExecutePage: View {
    let recipeTitle: String
    let type: RecipeType
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        TypeChip(type: type)
                        Text(recipeTitle)
                            .font(.system(.title, design: .serif).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let replayDate {
                            Label(
                                "Rejoue exactement l’essai du \(replayDate.formatted(.dateTime.day().month(.abbreviated))) — paramètres réels appliqués.",
                                systemImage: "arrow.trianglehead.counterclockwise"
                            )
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.green)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    ParamsGrid(items: displayParams, big: true)

                    if !version.steps.isEmpty {
                        Divider()
                        StepsList(steps: version.steps, big: true)
                    }
                }
                .padding()
                .padding(.bottom, 12)
            }

            VStack {
                Button(action: onDone) {
                    Text("Terminé — noter cet essai")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("execute-done-button")
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("v\(version.number)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
