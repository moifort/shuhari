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
    let onDelete: (Int) -> Void
    let onSelect: (Int) -> Void
    @State private var pendingDeletion: Item?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if trials.isEmpty {
                    ContentUnavailableView(
                        "Aucun essai en attente",
                        systemImage: "flask",
                        description: Text("Note un essai depuis la fiche pour lancer la boucle.")
                    )
                    .accessibilityIdentifier("next-trials-empty")
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingDeletion = item
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                                .accessibilityIdentifier("delete-trial-v\(item.versionNumber)")
                            }
                        }
                    }
                    .contentMargins(.top, Theme.Spacing.s, for: .scrollContent)
                }
            }
            .navigationTitle("Essais")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityIdentifier("close-next-trials")
                    .accessibilityLabel("Fermer")
                }
            }
            .alert(
                "Supprimer cet essai ?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                presenting: pendingDeletion
            ) { item in
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    onDelete(item.versionNumber)
                }
                .accessibilityIdentifier("confirm-delete-trial")
            } message: { _ in
                Text("Cette version en attente d'essai sera définitivement supprimée. Action irréversible.")
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
                onDelete: { _ in },
                onSelect: { _ in }
            )
        }
}

#Preview("Vide") {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            NextTrialsSheet(trials: [], onDelete: { _ in }, onSelect: { _ in })
        }
}
