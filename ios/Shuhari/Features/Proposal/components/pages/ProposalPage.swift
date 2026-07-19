import SwiftUI

/// The AI proposal screen: a short summary of what changes and why, then the
/// FULL proposed next version — ingredients and steps, each row editable inline
/// and tinted when it differs from the base version. Finally Valider/Fermer.
///
/// Diff highlighting: rows are always editable `TextField`s, so a from→to
/// `DiffValue` doesn't fit; instead a row carries the `Theme.Status.changed` tint
/// whenever its current value differs from the base version (new or modified). It
/// updates live as the user types.
///
/// The proposal is ephemeral (never persisted): "Fermer" discards it, "Valider"
/// accepts it. On accept the page emits the COMPLETE proposal (full-replacement
/// semantics) — the `basedOn`, `changeSummary` and `rationale` carried through from
/// the in-memory AI proposal, the ingredient and step lists taken from the
/// form's current (possibly edited) state.
struct ProposalPage: View {
    let type: RecipeType
    let proposal: Proposal
    let nextVersionNumber: Int
    /// The base version's content, to highlight what the proposal changes.
    let baseIngredients: [Ingredient]
    let baseSteps: [String]
    let isWorking: Bool
    let onClose: () -> Void
    let onValidate: (_ edited: ProposalEdit) -> Void

    private struct EditableIngredient: Identifiable {
        let id = UUID()
        var name: String
        var quantity: String
    }

    private struct EditableStep: Identifiable {
        let id = UUID()
        var text: String
        /// Per-step Thermomix settings, read-only, aligned with this step
        /// (`.plain` when the step carries none).
        let tmx: TmxSettings
    }

    @State private var ingredients: [EditableIngredient]
    @State private var steps: [EditableStep]

    init(
        type: RecipeType,
        proposal: Proposal,
        nextVersionNumber: Int,
        baseIngredients: [Ingredient],
        baseSteps: [String],
        isWorking: Bool,
        onClose: @escaping () -> Void,
        onValidate: @escaping (_ edited: ProposalEdit) -> Void
    ) {
        self.type = type
        self.proposal = proposal
        self.nextVersionNumber = nextVersionNumber
        self.baseIngredients = baseIngredients
        self.baseSteps = baseSteps
        self.isWorking = isWorking
        self.onClose = onClose
        self.onValidate = onValidate
        self._ingredients = State(initialValue: proposal.ingredients.map {
            EditableIngredient(name: $0.name, quantity: $0.quantity)
        })
        self._steps = State(initialValue: proposal.steps.enumerated().map { index, text in
            EditableStep(text: text, tmx: proposal.tmxSteps[safe: index] ?? .plain)
        })
    }

    var body: some View {
        List {
            summarySection
            if !ingredients.isEmpty {
                ingredientsSection
            }
            stepsSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Proposition")
        .navigationBarTitleDisplayMode(.inline)
        // "Fermer" = discard the proposal (nothing is persisted); "Valider" = accept.
        // Hiding the back button makes Fermer own the leading slot and disables the
        // back-swipe, so the only exits are an explicit decision.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .disabled(isWorking)
                .accessibilityIdentifier("close-proposal-button")
                .accessibilityLabel("Fermer")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onValidate(currentProposal)
                } label: {
                    if isWorking { ProgressView() } else { Image(systemName: "checkmark") }
                }
                .disabled(isWorking)
                .accessibilityIdentifier("validate-proposal-button")
                .accessibilityLabel("Valider")
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(proposal.changeSummary)
                    .font(.headline)
                Text(proposal.rationale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        Section("Ingrédients") {
            ForEach($ingredients) { $ingredient in
                HStack {
                    TextField("Ingrédient", text: $ingredient.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("edit-ingredient-name")
                    TextField("Quantité", text: $ingredient.quantity)
                        .fixedSize()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("edit-ingredient-quantity")
                }
                .listRowBackground(ingredientDiffers(ingredient) ? Theme.Status.changed.opacity(0.08) : nil)
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        Section("Étapes") {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Étape", text: $steps[index].text, axis: .vertical)
                            .lineLimit(1...6)
                            .accessibilityIdentifier("edit-step")
                        if !step.tmx.isEmpty {
                            TmxSettingBadges(
                                time: step.tmx.time,
                                temperature: step.tmx.temperature,
                                speed: step.tmx.speed,
                                reverse: step.tmx.reverse
                            )
                        }
                    }
                }
                .listRowBackground(stepDiffers(step.text) ? Theme.Status.changed.opacity(0.08) : nil)
            }
        }
    }

    // MARK: - Diff

    /// An ingredient row differs from the base version when the base has no
    /// ingredient with the exact same name and quantity (new or modified).
    private func ingredientDiffers(_ ingredient: EditableIngredient) -> Bool {
        !baseIngredients.contains { $0.name == ingredient.name && $0.quantity == ingredient.quantity }
    }

    /// A step differs when its exact text is absent from the base version's steps.
    private func stepDiffers(_ text: String) -> Bool {
        !baseSteps.contains(text)
    }

    // MARK: - Accepted proposal

    private var currentIngredients: [Ingredient] {
        ingredients.compactMap { row in
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = row.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !quantity.isEmpty else { return nil }
            return Ingredient(name: name, quantity: quantity)
        }
    }

    /// The COMPLETE proposal to accept: the AI summary, rationale and `basedOn`
    /// carried through unchanged, the ingredient and step lists from the form's
    /// current state. The proposal always carries the COMPLETE lists, and steps
    /// stay aligned with their per-step Thermomix settings.
    private var currentProposal: ProposalEdit {
        // Drop emptied steps, carrying each surviving row's tmx settings so `steps`
        // and `tmxSteps` keep the same length — a cleared step must not desync them
        // (a length mismatch makes the backend drop ALL Thermomix settings).
        let survivingSteps = steps.compactMap { row -> (text: String, tmx: TmxSettings)? in
            let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return (text, row.tmx)
        }
        let editedSteps = survivingSteps.map(\.text)
        // Empty for a non-Thermomix recipe (the proposal had no tmxSteps);
        // otherwise aligned 1:1 with the surviving steps.
        let editedTmxSteps: [TmxSettings] = proposal.tmxSteps.isEmpty ? [] : survivingSteps.map(\.tmx)

        return ProposalEdit(
            basedOn: proposal.basedOn,
            changeSummary: proposal.changeSummary,
            rationale: proposal.rationale,
            ingredients: currentIngredients,
            steps: editedSteps,
            tmxSteps: editedTmxSteps
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ProposalPage(
            type: .dish,
            proposal: Fixtures.proposal,
            nextVersionNumber: 5,
            baseIngredients: Fixtures.bourguignonV4.ingredients,
            baseSteps: Fixtures.bourguignonV4.steps,
            isWorking: false,
            onClose: {},
            onValidate: { _ in }
        )
    }
}
