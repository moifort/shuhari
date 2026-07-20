import SwiftUI

/// A minimal edit sheet for what a recipe can be retouched on: its title and its
/// course. The type stays fixed — a dish never becomes a Thermomix recipe, its
/// versions are shaped by it.
struct RecipeEditSheet: View {
    let initialTitle: String
    let initialCategory: DishCategory
    let onSave: (_ title: String, _ category: DishCategory) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var category: DishCategory
    @State private var error = ErrorPresenter()

    init(
        initialTitle: String,
        initialCategory: DishCategory,
        onSave: @escaping (_ title: String, _ category: DishCategory) async throws -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialCategory = initialCategory
        self.onSave = onSave
        self._title = State(initialValue: initialTitle)
        self._category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titre") {
                    TextField("Titre", text: $title)
                        .accessibilityIdentifier("edit-title-field")
                }
                Section {
                    IconPicker(
                        title: "Catégorie",
                        systemImage: "tag",
                        options: DishCategory.allCases,
                        icon: \.iconImage,
                        label: \.label,
                        selection: $category
                    )
                    .accessibilityIdentifier("edit-category-picker")
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(error.isRunning)
                    .accessibilityLabel("Annuler")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await error.run {
                                try await onSave(
                                    title.trimmingCharacters(in: .whitespacesAndNewlines),
                                    category
                                )
                            } onSuccess: { dismiss() }
                        }
                    } label: {
                        ActionIcon(systemImage: "checkmark", isRunning: error.isRunning)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || error.isRunning)
                    .accessibilityLabel("Enregistrer")
                }
            }
            .errorAlert(error)
        }
        // A swipe while the edit is being written would orphan the task.
        .interactiveDismissDisabled(error.isRunning)
    }
}

#Preview {
    Text("Fond")
        .sheet(isPresented: .constant(true)) {
            RecipeEditSheet(
                initialTitle: "Espresso — Brésil Santa Lúcia",
                initialCategory: .drink
            ) { _, _ in }
        }
}
