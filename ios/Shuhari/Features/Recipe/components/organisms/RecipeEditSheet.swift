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
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Annuler")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await error.run {
                                try await onSave(
                                    title.trimmingCharacters(in: .whitespacesAndNewlines),
                                    subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : subtitle
                                )
                            } onSuccess: { dismiss() }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || error.isRunning)
                    .accessibilityLabel("Enregistrer")
                }
            }
            .errorAlert(error)
        }
    }
}

#Preview {
    Text("Fond")
        .sheet(isPresented: .constant(true)) {
            RecipeEditSheet(
                initialTitle: "Espresso — Brésil Santa Lúcia",
                initialSubtitle: "Torréfaction claire"
            ) { _, _ in }
        }
}
