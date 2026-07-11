import SwiftUI

/// A minimal rename sheet for a recipe's title and subtitle.
struct RecipeEditSheet: View {
    let initialTitle: String
    let initialSubtitle: String
    let onSave: (_ title: String, _ subtitle: String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var subtitle: String
    @State private var error = ErrorPresenter()

    init(
        initialTitle: String,
        initialSubtitle: String,
        onSave: @escaping (_ title: String, _ subtitle: String?) async throws -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialSubtitle = initialSubtitle
        self.onSave = onSave
        self._title = State(initialValue: initialTitle)
        self._subtitle = State(initialValue: initialSubtitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titre") {
                    TextField("Titre", text: $title)
                        .accessibilityIdentifier("edit-title-field")
                }
                Section("Sous-titre") {
                    TextField("Sous-titre", text: $subtitle, axis: .vertical)
                        .accessibilityIdentifier("edit-subtitle-field")
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            await error.run {
                                try await onSave(
                                    title.trimmingCharacters(in: .whitespacesAndNewlines),
                                    subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : subtitle
                                )
                            } onSuccess: { dismiss() }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || error.isRunning)
                }
            }
            .errorAlert(error)
        }
    }
}
