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
            Label("La v\(versionNumber) a fait ses preuves — \(note)/10", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
            Text("La promouvoir en version courante ? Elle deviendra ta référence reproductible pour \(recipeTitle).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onPromote) {
                Group {
                    if isWorking { ProgressView() } else { Text("Promouvoir la v\(versionNumber)") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(isWorking)
            .accessibilityIdentifier("promote-button")

            Button("Plus tard — encore un essai", action: onLater)
                .frame(maxWidth: .infinity)
                .disabled(isWorking)
                .accessibilityIdentifier("promote-later-button")
        }
        .padding(20)
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
                note: 9,
                isWorking: false,
                onPromote: {},
                onLater: {}
            )
        }
}
