import SwiftUI

/// The AI draft screen: a short summary of what changes and why, then the FULL
/// draft of the next version — ingredients and steps, each row editable inline and
/// tinted when it differs from the base version. Finally Valider/Fermer.
///
/// Diff highlighting: rows are always editable `TextField`s, so a from→to
/// `DiffValue` doesn't fit; instead a row carries the `Theme.Status.changed` tint
/// whenever its current value differs from the base version (new or modified). It
/// updates live as the user types.
///
/// The draft is ephemeral (never persisted): Fermer discards it, Valider accepts it.
/// On accept the page emits the COMPLETE draft (full-replacement semantics) — the
/// `changeSummary` and `rationale` carried through from the in-memory AI draft, the
/// ingredient and step lists taken from the form's current (possibly edited) state.
struct DraftPage: View {
    let type: RecipeType
    let draft: Draft
    let nextVersionNumber: Int
    /// The base version's content, to highlight what the draft changes.
    let baseIngredients: [Ingredient]
    let baseSteps: [String]
    let isWorking: Bool
    let onClose: () -> Void
    let onValidate: (_ edited: DraftEdit) -> Void

    private struct EditableIngredient: Identifiable {
        let id = UUID()
        var name: String
        var quantity: String
    }

    private struct EditableStep: Identifiable {
        let id = UUID()
        var text: String
        /// Per-step Thermomix settings, read-only, aligned with this step.
        let tmx: TmxSettings?
    }

    @State private var ingredients: [EditableIngredient]
    @State private var steps: [EditableStep]

    init(
        type: RecipeType,
        draft: Draft,
        nextVersionNumber: Int,
        baseIngredients: [Ingredient],
        baseSteps: [String],
        isWorking: Bool,
        onClose: @escaping () -> Void,
        onValidate: @escaping (_ edited: DraftEdit) -> Void
    ) {
        self.type = type
        self.draft = draft
        self.nextVersionNumber = nextVersionNumber
        self.baseIngredients = baseIngredients
        self.baseSteps = baseSteps
        self.isWorking = isWorking
        self.onClose = onClose
        self.onValidate = onValidate
        self._ingredients = State(initialValue: draft.ingredients.map {
            EditableIngredient(name: $0.name, quantity: $0.quantity)
        })
        self._steps = State(initialValue: draft.steps.enumerated().map { index, text in
            EditableStep(text: text, tmx: draft.tmxSteps[safe: index] ?? nil)
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
        // Fermer = discard the draft (nothing is persisted); Valider = accept. Hiding
        // the back button makes Fermer own the leading slot and disables the
        // back-swipe, so the only exits are an explicit decision.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .disabled(isWorking)
                .accessibilityIdentifier("close-draft-button")
                .accessibilityLabel("Fermer")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onValidate(currentDraft)
                } label: {
                    if isWorking { ProgressView() } else { Image(systemName: "checkmark") }
                }
                .disabled(isWorking)
                .accessibilityIdentifier("validate-draft-button")
                .accessibilityLabel("Valider")
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(draft.changeSummary)
                    .font(.headline)
                Text(draft.rationale)
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
                        if let tmx = step.tmx, !tmx.isEmpty {
                            TmxSettingBadges(
                                time: tmx.time,
                                temperature: tmx.temperature,
                                speed: tmx.speed,
                                reverse: tmx.reverse
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

    // MARK: - Accepted draft

    private var currentIngredients: [Ingredient] {
        ingredients.compactMap { row in
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = row.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !quantity.isEmpty else { return nil }
            return Ingredient(name: name, quantity: quantity)
        }
    }

    /// The COMPLETE draft to accept: the AI summary and rationale carried through
    /// unchanged, the ingredient and step lists from the form's current state. The
    /// draft always carries the COMPLETE lists, and steps stay aligned with their
    /// per-step Thermomix settings.
    private var currentDraft: DraftEdit {
        // Drop emptied steps, carrying each surviving row's tmx settings so `steps`
        // and `tmxSteps` keep the same length — a cleared step must not desync them
        // (a length mismatch makes the backend drop ALL Thermomix settings).
        let survivingSteps = steps.compactMap { row -> (text: String, tmx: TmxSettings?)? in
            let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return (text, row.tmx)
        }
        let editedSteps = survivingSteps.map(\.text)
        // Empty for a non-Thermomix recipe (the draft had no tmxSteps); otherwise
        // aligned 1:1 with the surviving steps.
        let editedTmxSteps: [TmxSettings?] = draft.tmxSteps.isEmpty ? [] : survivingSteps.map(\.tmx)

        return DraftEdit(
            changeSummary: draft.changeSummary,
            rationale: draft.rationale,
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
        DraftPage(
            type: .plat,
            draft: Fixtures.draft,
            nextVersionNumber: 5,
            baseIngredients: Fixtures.bourguignonV4.ingredients,
            baseSteps: Fixtures.bourguignonV4.steps,
            isWorking: false,
            onClose: {},
            onValidate: { _ in }
        )
    }
}
