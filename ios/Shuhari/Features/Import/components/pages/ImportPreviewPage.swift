import SwiftUI

/// The editable import preview: title, detected type, parameters, steps and
/// source. Everything is adjustable before creating the recipe (v1).
struct ImportPreviewPage: View {
    let analysis: ImportAnalysis
    let isSaving: Bool
    let onSave: (ImportAnalysis) -> Void

    @State private var title: String
    @State private var type: RecipeType
    @State private var values: [String: String]

    init(analysis: ImportAnalysis, isSaving: Bool, onSave: @escaping (ImportAnalysis) -> Void) {
        self.analysis = analysis
        self.isSaving = isSaving
        self.onSave = onSave
        self._title = State(initialValue: analysis.title)
        self._type = State(initialValue: analysis.type)
        self._values = State(initialValue: Dictionary(uniqueKeysWithValues: analysis.params.map { ($0.key, $0.value) }))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Recette structurée", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.green)
                    Text("Relis et ajuste")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text("L’IA a mis la recette au format Carnet. Tout est modifiable avant d’enregistrer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                fieldLabel("Titre")
                TextField("Titre", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("import-title-field")

                fieldLabel("Type détecté")
                Picker("Type", selection: $type) {
                    ForEach(RecipeType.allCases) { candidate in
                        Text(candidate.label).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("import-type-picker")

                fieldLabel("Paramètres")
                VStack(spacing: 10) {
                    ForEach(analysis.params) { param in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(param.key)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(.tertiary)
                            TextField(param.value, text: binding(for: param.key))
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                fieldLabel("Étapes")
                VStack(alignment: .leading) {
                    StepsList(steps: analysis.steps)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .carnetCard()

                if let source = analysis.sourceLabel, !source.isEmpty {
                    Text("Source : \(source)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Button {
                    onSave(edited)
                } label: {
                    Group {
                        if isSaving { ProgressView() } else { Text("Enregistrer la recette (v1)") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityIdentifier("save-recipe-button")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Aperçu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var edited: ImportAnalysis {
        ImportAnalysis(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: analysis.subtitle,
            type: type,
            params: analysis.params.map { Param(key: $0.key, value: values[$0.key] ?? $0.value) },
            steps: analysis.steps,
            sourceLabel: analysis.sourceLabel
        )
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
