import SwiftUI

/// The AI proposal screen: a short summary of what changes and why, then the FULL
/// draft of the next version — ingredients and steps, each row editable inline and
/// tinted when it differs from the base version. Finally Valider/Refuser.
///
/// Diff highlighting: rows are always editable `TextField`s, so a from→to
/// `DiffValue` doesn't fit; instead a row carries the `Theme.Status.changed` tint
/// whenever its current value differs from the base version (new or modified). It
/// updates live as the user types.
///
/// On accept the page sends an `editedDraft` only when the user actually changed
/// something versus the AI draft; the draft always carries the COMPLETE lists
/// (full-replacement semantics).
struct ProposalPage: View {
    let recipeTitle: String
    let type: RecipeType
    let proposal: Proposal
    let nextVersionNumber: Int
    /// The base version's content, to highlight what the draft changes.
    let baseIngredients: [Ingredient]
    let baseSteps: [String]
    let isWorking: Bool
    let onRefuse: () -> Void
    let onValidate: (_ editedDraft: ProposalDraft?) -> Void

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
        recipeTitle: String,
        type: RecipeType,
        proposal: Proposal,
        nextVersionNumber: Int,
        baseIngredients: [Ingredient],
        baseSteps: [String],
        isWorking: Bool,
        onRefuse: @escaping () -> Void,
        onValidate: @escaping (_ editedDraft: ProposalDraft?) -> Void
    ) {
        self.recipeTitle = recipeTitle
        self.type = type
        self.proposal = proposal
        self.nextVersionNumber = nextVersionNumber
        self.baseIngredients = baseIngredients
        self.baseSteps = baseSteps
        self.isWorking = isWorking
        self.onRefuse = onRefuse
        self.onValidate = onValidate
        self._ingredients = State(initialValue: proposal.ingredients.map {
            EditableIngredient(name: $0.name, quantity: $0.quantity)
        })
        self._steps = State(initialValue: proposal.steps.enumerated().map { index, text in
            EditableStep(text: text, tmx: proposal.tmxSteps[safe: index] ?? nil)
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
        .navigationSubtitle(recipeTitle)
        .safeAreaInset(edge: .bottom) {
            GlassEffectContainer {
                VStack(spacing: 10) {
                    Button {
                        onValidate(editedDraftIfChanged)
                    } label: {
                        Group {
                            if isWorking { ProgressView() } else {
                                Text("Valider — créer la v\(nextVersionNumber)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(isWorking)
                    .accessibilityIdentifier("validate-proposal-button")

                    Button("Refuser la proposition", role: .destructive, action: onRefuse)
                        .buttonStyle(.glass)
                        .tint(.red)
                        .disabled(isWorking)
                        .accessibilityIdentifier("refuse-proposal-button")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
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
        } header: {
            Label("Ce qui change — proposition de l’IA", systemImage: "flask.fill")
                .foregroundStyle(Theme.Status.toTest)
                .textCase(nil)
        } footer: {
            Text("D’après ton essai sur la v\(proposal.versionNumber) — rien n’est créé sans ta validation. Retouche librement le brouillon avant de valider.")
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

    // MARK: - Edited draft

    private var currentIngredients: [Ingredient] {
        ingredients.compactMap { row in
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = row.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !quantity.isEmpty else { return nil }
            return Ingredient(name: name, quantity: quantity)
        }
    }

    /// Only send an edited draft when the user changed the ingredients or steps
    /// versus the AI draft. The draft always carries the COMPLETE lists, and steps
    /// stay aligned with their per-step Thermomix settings.
    private var editedDraftIfChanged: ProposalDraft? {
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
        let editedTmxSteps: [TmxSettings?] = proposal.tmxSteps.isEmpty ? [] : survivingSteps.map(\.tmx)

        let ingredientsChanged = currentIngredients != proposal.ingredients
        let stepsChanged = editedSteps != proposal.steps
        guard ingredientsChanged || stepsChanged else { return nil }
        return ProposalDraft(
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
            recipeTitle: Fixtures.bourguignon.title,
            type: .plat,
            proposal: Fixtures.proposal,
            nextVersionNumber: 5,
            baseIngredients: Fixtures.bourguignonV4.ingredients,
            baseSteps: Fixtures.bourguignonV4.steps,
            isWorking: false,
            onRefuse: {},
            onValidate: { _ in }
        )
    }
}
