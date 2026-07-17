import SwiftUI

/// The recipe's trials — both the upcoming versions still awaiting a first run
/// and the journal of essais already carried out — presented from the fiche's
/// beaker CTA. A half-screen sheet (detent .medium) that dims the fiche behind
/// it, so a tap outside dismisses it; tapping an upcoming row launches that
/// version's trial capture. The past section is read-only.
struct NextTrialsSheet: View {
    struct Item: Identifiable {
        let versionNumber: Int
        let change: String?
        let why: String?
        var id: Int { versionNumber }
    }

    struct PastItem: Identifiable {
        let id: String
        let versionNumber: Int
        let note: Int
        let remarks: String
        let date: Date
    }

    let trials: [Item]
    let pastTrials: [PastItem]
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
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
                } header: {
                    Text("Prochains essais")
                }

                Section {
                    if pastTrials.isEmpty {
                        Text("Aucun essai réalisé pour le moment.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pastTrials) { item in
                            TrialRow(
                                recipeTitle: nil,
                                versionNumber: item.versionNumber,
                                note: item.note,
                                remarks: item.remarks,
                                date: item.date
                            )
                            .accessibilityIdentifier("sheet-trial-row-\(item.id)")
                        }
                    }
                } header: {
                    Text(pastTrials.isEmpty ? "Journal d’essais" : "Journal d’essais (\(pastTrials.count))")
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
                pastTrials: Fixtures.bourguignonEssais.map {
                    .init(
                        id: "\($0.number)",
                        versionNumber: $0.number,
                        note: $0.note ?? 0,
                        remarks: $0.remarks ?? "",
                        date: $0.executedAt ?? $0.createdAt
                    )
                },
                onSelect: { _ in }
            )
        }
}

#Preview("Vide") {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            NextTrialsSheet(trials: [], pastTrials: [], onSelect: { _ in })
        }
}

#Preview("Prochains vides, journal plein") {
    Text("Fiche recette")
        .sheet(isPresented: .constant(true)) {
            NextTrialsSheet(
                trials: [],
                pastTrials: Fixtures.bourguignonEssais.map {
                    .init(
                        id: "\($0.number)",
                        versionNumber: $0.number,
                        note: $0.note ?? 0,
                        remarks: $0.remarks ?? "",
                        date: $0.executedAt ?? $0.createdAt
                    )
                },
                onSelect: { _ in }
            )
        }
}
