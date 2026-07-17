import SwiftUI

/// The recipe's upcoming trials — the versions still awaiting a first run —
/// as a compact list, presented from the fiche's beaker CTA. A half-screen
/// sheet (detent .medium) that stays up while the fiche scrolls behind it;
/// tapping a row launches that version's trial capture. Empty when every
/// version has already been tried.
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
            Group {
                if trials.isEmpty {
                    ContentUnavailableView(
                        "Aucun essai pour le moment",
                        systemImage: "flask",
                        description: Text("Les versions à essayer apparaîtront ici.")
                    )
                } else {
                    List {
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
            }
            .navigationTitle("Prochains essais")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("next-trials-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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
