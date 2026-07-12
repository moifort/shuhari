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
        Form {
            Section {
                TextField("Titre", text: $title)
                    .accessibilityIdentifier("import-title-field")
            } header: {
                Label("Recette structurée — relis et ajuste", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .textCase(nil)
            } footer: {
                Text("L’IA a mis la recette au format Carnet. Tout est modifiable avant d’enregistrer.")
            }

            Section("Type détecté") {
                Picker("Type", selection: $type) {
                    ForEach(RecipeType.allCases) { candidate in
                        Text(candidate.label).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("import-type-picker")
            }

            Section("Paramètres") {
                ForEach(analysis.params) { param in
                    LabeledContent(param.key) {
                        TextField(param.value, text: binding(for: param.key))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                StepsList(steps: analysis.steps)
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
        .safeAreaInset(edge: .bottom) {
            Button {
                onSave(edited)
            } label: {
                Group {
                    if isSaving { ProgressView() } else { Text("Enregistrer la recette (v1)") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            .accessibilityIdentifier("save-recipe-button")
            .padding(.horizontal)
            .padding(.bottom, 8)
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
