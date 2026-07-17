import SwiftUI

/// Offered after a high-scoring trial: promote the pending version to the current
/// reference, or keep experimenting.
struct PromotionSheet: View {
    let recipeTitle: String
    let versionNumber: Int
    let note: Int
    let isWorking: Bool
    let onPromote: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("La v\(versionNumber) a fait ses preuves — \(note)/5", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(Theme.Status.current)
                .fixedSize(horizontal: false, vertical: true)
            Text("La promouvoir en version courante ? Elle deviendra ta référence reproductible pour \(recipeTitle).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GlassEffectContainer {
                VStack(spacing: Theme.Spacing.m) {
                    Button(action: onPromote) {
                        Group {
                            if isWorking { ProgressView() } else { Text("Promouvoir la v\(versionNumber)") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.Status.current)
                    .controlSize(.large)
                    .disabled(isWorking)
                    .accessibilityIdentifier("promote-button")

                    Button("Plus tard — encore un essai", action: onLater)
                        .buttonStyle(.glass)
                        .frame(maxWidth: .infinity)
                        .disabled(isWorking)
                        .accessibilityIdentifier("promote-later-button")
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Fond")
        .sheet(isPresented: .constant(true)) {
            PromotionSheet(
                recipeTitle: "Espresso — Brésil",
                versionNumber: 4,
                note: 5,
                isWorking: false,
                onPromote: {},
                onLater: {}
            )
        }
}
