import SwiftUI

/// The editable import preview: title, detected type and dish category,
/// ingredients and steps. Everything is adjustable before creating the recipe
/// (v1). Presented inside the import review sheet — its actions live in the sheet
/// toolbar (Fermer / Valider), not a bottom button.
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
    @State private var category: DishCategory
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
        self._category = State(initialValue: analysis.category)
        self._ingredients = State(initialValue: analysis.ingredients.map {
            EditableIngredient(name: $0.name, quantity: $0.quantity)
        })
        self._stepTexts = State(initialValue: analysis.steps.map(\.text))
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

                LabeledContent {
                    Menu {
                        Picker("Type", selection: $type) {
                            ForEach(RecipeType.allCases) { candidate in
                                pickerRow(icon: candidate.iconImage(filled: false), label: candidate.label)
                                    .tag(candidate)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        pickerValue(icon: type.iconImage(filled: false), label: type.label)
                    }
                    .tint(.secondary)
                    .accessibilityIdentifier("import-type-picker")
                } label: {
                    Label("Type", systemImage: "square.grid.2x2")
                }

                LabeledContent {
                    Menu {
                        Picker("Catégorie", selection: $category) {
                            ForEach(DishCategory.allCases) { candidate in
                                pickerRow(icon: candidate.iconImage, label: candidate.label)
                                    .tag(candidate)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        pickerValue(icon: category.iconImage, label: category.label)
                    }
                    .tint(.secondary)
                    .accessibilityIdentifier("import-category-picker")
                } label: {
                    Label("Catégorie", systemImage: "tag")
                }
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
                Button { onCancel() } label: {
                    Image(systemName: "xmark")
                }
                .disabled(isSaving)
                .accessibilityLabel("Fermer")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onSave(edited)
                } label: {
                    ActionIcon(systemImage: "checkmark", isRunning: isSaving)
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityLabel("Valider")
                .accessibilityIdentifier("save-recipe-button")
            }
        }
    }

    /// One option inside the open dropdown. The menu strips styling modifiers from
    /// its rows, so this only carries the icon and the label — sizing it here has
    /// no effect.
    private func pickerRow(icon: Image, label: String) -> some View {
        Label { Text(label) } icon: { icon }
    }

    /// The selected value shown on the row. It is spelled out rather than left to a
    /// `Picker`, which renders its collapsed value through the system and drops
    /// every modifier — `.imageScale`, `.font` and even `.resizable().frame()` are
    /// all ignored there, leaving an icon far larger than the dropdown's. Driving a
    /// `Menu` label instead is what makes the icon sizable at all.
    private func pickerValue(icon: Image, label: String) -> some View {
        HStack(spacing: 6) {
            icon.imageScale(.small)
            Text(label)
            Image(systemName: "chevron.up.chevron.down")
                .imageScale(.small)
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
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
                thermomixBadges(at: index)
            }
        }
    }

    @ViewBuilder
    private func thermomixBadges(at index: Int) -> some View {
        if let step = analysis.steps[safe: index], !step.settings.isEmpty {
            ThermomixSettingBadges(
                time: step.settings.time,
                temperature: step.settings.temperature,
                speed: step.settings.speed,
                reverse: step.settings.reverse
            )
        }
    }

    private var edited: ImportAnalysis {
        // Drop blank steps (the server rejects empty StepText); each surviving step
        // keeps its own settings (`.plain` when it has none).
        let trimmedSteps = stepTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let keptIndices = trimmedSteps.indices.filter { !trimmedSteps[$0].isEmpty }
        let steps = keptIndices.map { index in
            ThermomixStep(text: trimmedSteps[index], settings: analysis.steps[safe: index]?.settings ?? .plain)
        }
        return ImportAnalysis(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            category: category,
            ingredients: ingredients.compactMap { row in
                let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let quantity = row.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !quantity.isEmpty else { return nil }
                return Ingredient(name: name, quantity: quantity)
            },
            steps: steps,
            sourceLabel: analysis.sourceLabel
        )
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
        ImportPreviewPage(analysis: Fixtures.importAnalysisThermomix, isSaving: false, onCancel: {}, onSave: { _ in })
    }
}
