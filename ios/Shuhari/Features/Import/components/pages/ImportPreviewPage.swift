import SwiftUI

/// The editable import preview: title, detected type, parameters, steps and
/// source. Everything is adjustable before creating the recipe (v1). Presented
/// inside the import review sheet — its actions live in the sheet toolbar
/// (Fermer / Valider), not a bottom button.
struct ImportPreviewPage: View {
    let analysis: ImportAnalysis
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (ImportAnalysis) -> Void

    @State private var title: String
    @State private var type: RecipeType
    @State private var values: [String: String]

    init(
        analysis: ImportAnalysis,
        isSaving: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ImportAnalysis) -> Void
    ) {
        self.analysis = analysis
        self.isSaving = isSaving
        self.onCancel = onCancel
        self.onSave = onSave
        self._title = State(initialValue: analysis.title)
        self._type = State(initialValue: analysis.type)
        self._values = State(initialValue: Dictionary(uniqueKeysWithValues: analysis.params.map { ($0.key, $0.value) }))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    TextField("Titre", text: $title)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("import-title-field")
                } label: {
                    Label("Titre", systemImage: "textformat")
                }

                Picker(selection: $type) {
                    ForEach(RecipeType.allCases) { candidate in
                        Text(candidate.label).tag(candidate)
                    }
                } label: {
                    Label("Type", systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("import-type-picker")
            } header: {
                Label("Recette structurée — relis et ajuste", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Status.current)
                    .textCase(nil)
            } footer: {
                Text("L’IA a mis la recette au format Carnet. Tout est modifiable avant d’enregistrer.")
            }

            Section("Paramètres") {
                ForEach(analysis.params) { param in
                    LabeledContent {
                        TextField(param.value, text: binding(for: param.key))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    } label: {
                        Text(param.key)
                    }
                }
            }

            Section {
                if let tmxItems = TmxStepsList.Item.zipped(steps: analysis.steps, tmxSteps: analysis.tmxSteps) {
                    TmxStepsList(items: tmxItems)
                } else {
                    StepsList(steps: analysis.steps)
                }
            } header: {
                Text("Étapes")
            } footer: {
                if let source = analysis.sourceLabel, !source.isEmpty {
                    Text("Source : \(source)")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Aperçu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer", systemImage: "xmark") { onCancel() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onSave(edited)
                } label: {
                    if isSaving { ProgressView() } else { Text("Valider") }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityIdentifier("save-recipe-button")
            }
        }
    }

    private var edited: ImportAnalysis {
        ImportAnalysis(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: analysis.subtitle,
            type: type,
            params: analysis.params.map { Param(key: $0.key, value: values[$0.key] ?? $0.value) },
            steps: analysis.steps,
            tmxSteps: analysis.tmxSteps,
            sourceLabel: analysis.sourceLabel
        )
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }
}

#Preview("Plat") {
    NavigationStack {
        ImportPreviewPage(analysis: Fixtures.importAnalysis, isSaving: false, onCancel: {}, onSave: { _ in })
    }
}

#Preview("Thermomix") {
    NavigationStack {
        ImportPreviewPage(analysis: Fixtures.importAnalysisTmx, isSaving: false, onCancel: {}, onSave: { _ in })
    }
}
