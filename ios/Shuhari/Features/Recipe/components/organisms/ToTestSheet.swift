import SwiftUI

/// The pending "à tester" version, presented as a non-modal bottom panel from the
/// fiche: it stays up (detent `.medium`) while the recipe stays scrollable behind
/// it, and drags away to dismiss. Reuses the shared `TestBanner`; its CTA opens the
/// trial capture directly.
struct ToTestSheet: View {
    let versionNumber: Int
    let change: String?
    let why: String?
    let type: RecipeType
    let onExecute: () -> Void

    var body: some View {
        List {
            Section {
                TestBanner(
                    title: nil,
                    versionNumber: versionNumber,
                    change: change,
                    why: why,
                    type: type,
                    onExecute: onExecute
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .accessibilityIdentifier("to-test-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}

#Preview {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            ToTestSheet(
                versionNumber: 4,
                change: "Cuisson 3 h → 3 h 30",
                why: "La viande était encore un peu ferme.",
                type: .plat,
                onExecute: {}
            )
        }
}
