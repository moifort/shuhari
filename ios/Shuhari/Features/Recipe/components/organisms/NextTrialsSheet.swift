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
    @Environment(\.dismiss) private var dismiss

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
            .contentMargins(.top, Theme.Spacing.s, for: .scrollContent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityIdentifier("close-next-trials")
                    .accessibilityLabel("Fermer")
                }
            }
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
                    .init(versionNumber: 6, change: "Sel 8 → 10 g", why: "Assaisonnement en retrait."),
                    .init(versionNumber: 5, change: "Cuisson 3 h → 3 h 30", why: "La viande était encore un peu ferme."),
                    .init(versionNumber: 4, change: "Température 93 → 92 °C", why: "Extraction trop amère."),
                    .init(versionNumber: 3, change: "Repos 10 → 20 min", why: nil),
                    .init(versionNumber: 2, change: "Oignons +50 g", why: "Manque de fond."),
                    .init(versionNumber: 1, change: nil, why: "Version d'origine importée."),
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
