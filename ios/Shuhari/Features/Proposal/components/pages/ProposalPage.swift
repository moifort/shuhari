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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                changesCard
                RuleChip(type: type)
                queuedCard
                choiceSection
                Spacer(minLength: 4)
                actions
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Proposition")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Proposition de l’IA", systemImage: "flask.fill")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.orange)
            Text("Itérer sur \(recipeTitle)")
                .font(.system(.title2, design: .serif).weight(.bold))
            Text("D’après ton essai sur la v\(proposal.versionNumber) — rien n’est créé sans ta validation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ce qui change")
            VStack(spacing: 10) {
                ForEach(proposal.vars) { variable in
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(variable.key)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(.tertiary)
                            TextField(variable.to, text: binding(for: variable.key))
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("edit-var-\(variable.key)")
                        }
                    } else {
                        DiffRow(key: variable.key, from: variable.from, to: editedTo[variable.key] ?? variable.to)
                    }
                }
            }
            Text(proposal.rationale)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carnetCard()
    }

    @ViewBuilder
    private var queuedCard: some View {
        if !proposal.queued.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pistes gardées pour la suite")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                ForEach(Array(proposal.queued.enumerated()), id: \.offset) { _, lead in
                    Label(lead, systemImage: "circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .labelStyle(BulletLabelStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .carnetCard()
        }
    }

    private var choiceSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "En faire…")
            Picker("En faire…", selection: $choice) {
                Text("Itération (v\(nextVersionNumber))").tag(ProposalRecommendation.iteration)
                Text("Variation").tag(ProposalRecommendation.variation)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("proposal-choice-picker")

            Text(choiceExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("Refuser", role: .destructive, action: onRefuse)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("refuse-proposal-button")
                Button(isEditing ? "Terminer" : "Modifier") { isEditing.toggle() }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("edit-proposal-button")
            }
            .buttonStyle(.bordered)
            .disabled(isWorking)

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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking)
            .accessibilityIdentifier("validate-proposal-button")
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

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.tertiary)
            configuration.title
        }
    }
}
