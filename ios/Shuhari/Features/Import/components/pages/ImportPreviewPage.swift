import SwiftUI

/// The editable import preview: title, detected type, ingredients, parameters and
/// steps. Everything is adjustable before creating the recipe (v1). Presented
/// inside the import review sheet — its actions live in the sheet toolbar
/// (Fermer / Valider), not a bottom button.
struct ImportPreviewPage: View {
    let analysis: ImportAnalysis
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (ImportAnalysis) -> Void

    /// Editable ingredient row — a stable identity so rows survive edits/deletes.
    private struct EditableIngredient: Identifiable {
        let id = UUID()
        var name: String
        var quantity: String
    }

    @State private var title: String
    @State private var type: RecipeType
    @State private var values: [String: String]
    @State private var ingredients: [EditableIngredient]
    @State private var stepTexts: [String]

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
        self._ingredients = State(initialValue: analysis.ingredients.map {
            EditableIngredient(name: $0.name, quantity: $0.quantity)
        })
        self._stepTexts = State(initialValue: analysis.steps)
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
                        Label(candidate.label, systemImage: candidate.icon).tag(candidate)
                    }
                } label: {
                    Label("Type", systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("import-type-picker")
            }

            if !ingredients.isEmpty {
                Section("Ingrédients") {
                    ForEach($ingredients) { $ingredient in
                        HStack {
                            TextField("Ingrédient", text: $ingredient.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TextField("Quantité", text: $ingredient.quantity)
                                .fixedSize()
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                }
            }

            if !analysis.params.isEmpty {
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
            }

            Section {
                ForEach(stepTexts.indices, id: \.self) { index in
                    stepRow(index)
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
                    if isSaving { ProgressView() } else { Image(systemName: "checkmark") }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityLabel("Valider")
                .accessibilityIdentifier("save-recipe-button")
            }
        }
    }

    /// A numbered, editable step. The step text is editable; the Thermomix
    /// settings (time / temperature / speed / reverse) stay read-only badges.
    private func stepRow(_ index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
            VStack(alignment: .leading, spacing: 6) {
                TextField("Étape", text: $stepTexts[index], axis: .vertical)
                    .lineLimit(1...6)
                tmxBadges(at: index)
            }
        }
    }

    @ViewBuilder
    private func tmxBadges(at index: Int) -> some View {
        if let settings = (analysis.tmxSteps?[safe: index]) ?? nil, !settings.isEmpty {
            TmxSettingBadges(
                time: settings.time,
                temperature: settings.temperature,
                speed: settings.speed,
                reverse: settings.reverse
            )
        }
    }

    private var edited: ImportAnalysis {
        // Drop blank steps (the server rejects empty StepText), keeping tmxSteps
        // aligned by the same surviving indices.
        let trimmedSteps = stepTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let keptIndices = trimmedSteps.indices.filter { !trimmedSteps[$0].isEmpty }
        let steps = keptIndices.map { trimmedSteps[$0] }
        let tmxSteps = analysis.tmxSteps.map { list in
            keptIndices.map { index in index < list.count ? list[index] : nil }
        }
        return ImportAnalysis(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: analysis.subtitle,
            type: type,
            params: analysis.params.map { Param(key: $0.key, value: values[$0.key] ?? $0.value) },
            ingredients: ingredients.compactMap { row in
                let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let quantity = row.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !quantity.isEmpty else { return nil }
                return Ingredient(name: name, quantity: quantity)
            },
            steps: steps,
            tmxSteps: tmxSteps,
            sourceLabel: analysis.sourceLabel
        )
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
