import SwiftUI

/// The tips proposal screen: the COMPLETE tips list the AI merged — the version's
/// current tips kept, what the cook just typed reworded and folded in. Each row is
/// editable inline and carries an orange dot when it differs from the version's
/// current tips (new or reworded), exactly like `ProposalPage`'s rows.
///
/// The proposal is ephemeral: "Fermer" discards it, "Valider" emits the complete
/// list, which replaces the version's tips in place. No version is ever created
/// here, so there is no "Nouvelle recette" way out either.
struct TipsProposalPage: View {
    /// The merged list proposed by the AI.
    let proposedTips: [String]
    /// The version's current tips, to mark what the proposal changes.
    let baseTips: [String]
    let isWorking: Bool
    let onClose: () -> Void
    let onValidate: (_ tips: [String]) -> Void

    private struct EditableTip: Identifiable {
        let id = UUID()
        var text: String
    }

    @State private var tips: [EditableTip]
    /// Height of one line of body text — the box the change dot centres itself in.
    @ScaledMetric(relativeTo: .body) private var bodyLineHeight: CGFloat = 20.5

    init(
        proposedTips: [String],
        baseTips: [String],
        isWorking: Bool,
        onClose: @escaping () -> Void,
        onValidate: @escaping (_ tips: [String]) -> Void
    ) {
        self.proposedTips = proposedTips
        self.baseTips = baseTips
        self.isWorking = isWorking
        self.onClose = onClose
        self.onValidate = onValidate
        self._tips = State(initialValue: proposedTips.map { EditableTip(text: $0) })
    }

    var body: some View {
        List {
            Section {
                ForEach($tips) { $tip in
                    HStack(alignment: .top, spacing: 12) {
                        changeDot(!baseTips.contains(tip.text))
                        TextField("Conseil", text: $tip.text, axis: .vertical)
                            .lineLimit(1...6)
                            .accessibilityIdentifier("edit-tip")
                    }
                }
            } footer: {
                // No section header: the navigation title already says "Conseils".
                Text("Vider un conseil le supprime.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Conseils")
        .navigationBarTitleDisplayMode(.inline)
        // Same contract as the version proposal: hiding the back button makes Fermer
        // own the leading slot, so the only exits are an explicit decision.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .disabled(isWorking)
                .accessibilityIdentifier("close-tips-proposal-button")
                .accessibilityLabel("Fermer")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onValidate(currentTips)
                } label: {
                    ActionIcon(systemImage: "checkmark", isRunning: isWorking)
                }
                .disabled(isWorking)
                .accessibilityIdentifier("validate-tips-button")
                .accessibilityLabel("Valider")
            }
        }
    }

    /// The orange dot marking a changed row, in a box one body line tall so a
    /// top-aligned row centres it on the first line of text. Filled clear (not
    /// removed) on an unchanged row so every row keeps the same leading alignment.
    private func changeDot(_ changed: Bool) -> some View {
        Circle()
            .fill(changed ? Theme.Status.changed : .clear)
            .frame(width: 7, height: 7)
            .frame(height: bodyLineHeight)
            .accessibilityHidden(true)
    }

    /// The complete list to save: the form's current state, emptied rows dropped.
    private var currentTips: [String] {
        tips.compactMap {
            let text = $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }
}

#Preview {
    NavigationStack {
        TipsProposalPage(
            proposedTips: [
                "Servir avec des tagliatelles fraîches.",
                "Se congèle très bien, jusqu’à trois mois.",
            ],
            baseTips: ["Servir avec des tagliatelles fraîches."],
            isWorking: false,
            onClose: {},
            onValidate: { _ in }
        )
    }
}
