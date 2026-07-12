import SwiftUI

/// The AI proposal screen: the highlighted diff, the rationale, the one-variable
/// rule reminder, queued leads, and the iteration/variation choice.
struct ProposalPage: View {
    let recipeTitle: String
    let type: RecipeType
    let proposal: Proposal
    let nextVersionNumber: Int
    let variationTitle: String?
    let isWorking: Bool
    let onRefuse: () -> Void
    let onValidate: (_ choice: ProposalRecommendation, _ editedVars: [ProposalVar]?) -> Void

    @State private var choice: ProposalRecommendation
    @State private var isEditing = false
    @State private var editedTo: [String: String]

    init(
        recipeTitle: String,
        type: RecipeType,
        proposal: Proposal,
        nextVersionNumber: Int,
        variationTitle: String?,
        isWorking: Bool,
        onRefuse: @escaping () -> Void,
        onValidate: @escaping (_ choice: ProposalRecommendation, _ editedVars: [ProposalVar]?) -> Void
    ) {
        self.recipeTitle = recipeTitle
        self.type = type
        self.proposal = proposal
        self.nextVersionNumber = nextVersionNumber
        self.variationTitle = variationTitle
        self.isWorking = isWorking
        self.onRefuse = onRefuse
        self.onValidate = onValidate
        self._choice = State(initialValue: proposal.recommendation)
        self._editedTo = State(initialValue: Dictionary(uniqueKeysWithValues: proposal.vars.map { ($0.key, $0.to) }))
    }

    var body: some View {
        List {
            changesSection
            queuedSection
            choiceSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Proposition")
        .navigationSubtitle(recipeTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Terminer" : "Modifier") { isEditing.toggle() }
                    .disabled(isWorking)
                    .accessibilityIdentifier("edit-proposal-button")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    onValidate(choice, editedVarsIfChanged)
                } label: {
                    Group {
                        if isWorking { ProgressView() } else {
                            Text(choice == .iteration ? "Valider — créer la v\(nextVersionNumber)" : "Valider — créer la variation")
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
                    .disabled(isWorking)
                    .accessibilityIdentifier("refuse-proposal-button")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var changesSection: some View {
        Section {
            ForEach(proposal.vars) { variable in
                if isEditing {
                    LabeledContent(variable.key) {
                        TextField(variable.to, text: binding(for: variable.key))
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("edit-var-\(variable.key)")
                    }
                } else {
                    DiffRow(key: variable.key, from: variable.from, to: editedTo[variable.key] ?? variable.to)
                }
            }
        } header: {
            Label("Ce qui change — proposition de l’IA", systemImage: "flask.fill")
                .foregroundStyle(.orange)
                .textCase(nil)
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("D’après ton essai sur la v\(proposal.versionNumber) — rien n’est créé sans ta validation.")
                Text(proposal.rationale)
                RuleChip(type: type)
            }
        }
    }

    @ViewBuilder
    private var queuedSection: some View {
        if !proposal.queued.isEmpty {
            Section("Pistes gardées pour la suite") {
                ForEach(Array(proposal.queued.enumerated()), id: \.offset) { _, lead in
                    Label(lead, systemImage: "lightbulb")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var choiceSection: some View {
        Section {
            Picker("En faire…", selection: $choice) {
                Text("Itération (v\(nextVersionNumber))").tag(ProposalRecommendation.iteration)
                Text("Variation").tag(ProposalRecommendation.variation)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("proposal-choice-picker")
        } header: {
            Text("En faire…")
        } footer: {
            Text(choiceExplanation)
        }
    }

    private var choiceExplanation: String {
        switch choice {
        case .iteration:
            return "La v\(nextVersionNumber) rejoint la lignée de \(recipeTitle) et devient « à tester »."
        case .variation:
            if let variationTitle {
                return "Crée « \(variationTitle) », une recette liée dérivée de \(recipeTitle), avec sa propre lignée."
            }
            return "Crée une nouvelle recette liée, dérivée de \(recipeTitle), avec sa propre lignée de versions."
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { editedTo[key] ?? "" },
            set: { editedTo[key] = $0 }
        )
    }

    /// Only send editedVars when the user actually changed a target value.
    private var editedVarsIfChanged: [ProposalVar]? {
        let changed = proposal.vars.contains { (editedTo[$0.key] ?? $0.to) != $0.to }
        guard changed else { return nil }
        return proposal.vars.map { ProposalVar(key: $0.key, from: $0.from, to: editedTo[$0.key] ?? $0.to) }
    }
}
