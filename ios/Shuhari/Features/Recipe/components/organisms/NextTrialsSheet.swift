import SwiftUI

/// The recipe's versions still awaiting a first run, presented from the fiche's
/// beaker CTA. A half-screen sheet (detent .medium) that dims the fiche behind
/// it, so a tap outside dismisses it; tapping a row launches that version's
/// trial capture.
struct NextTrialsSheet: View {
    struct Item: Identifiable {
        let versionNumber: Int
        let change: String?
        let why: String?
        var id: Int { versionNumber }
    }

    let trials: [Item]
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                if trials.isEmpty {
                    Text("Aucune version en attente d'essai.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trials) { item in
                        Button {
                            onSelect(item.versionNumber)
                        } label: {
                            NextTrialRow(
                                versionNumber: item.versionNumber,
                                change: item.change,
                                why: item.why
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("next-trial-v\(item.versionNumber)")
                    }
                }
            }
            .navigationTitle("Essais")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("next-trials-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Avec essais") {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            NextTrialsSheet(
                trials: [
                    .init(versionNumber: 4, change: "Cuisson 3 h → 3 h 30", why: "La viande était encore un peu ferme."),
                    .init(versionNumber: 2, change: "Température 93 → 92 °C", why: nil),
                ],
                onSelect: { _ in }
            )
        }
}

#Preview("Vide") {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            NextTrialsSheet(trials: [], onSelect: { _ in })
        }
}
