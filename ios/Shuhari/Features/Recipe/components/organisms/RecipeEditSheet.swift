import SwiftUI

/// A minimal rename sheet for a recipe's title.
struct RecipeEditSheet: View {
    let initialTitle: String
    let onSave: (_ title: String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var error = ErrorPresenter()

    init(initialTitle: String, onSave: @escaping (_ title: String) async throws -> Void) {
        self.initialTitle = initialTitle
        self.onSave = onSave
        self._title = State(initialValue: initialTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titre") {
                    TextField("Titre", text: $title)
                        .accessibilityIdentifier("edit-title-field")
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
                                try await onSave(title.trimmingCharacters(in: .whitespacesAndNewlines))
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
            RecipeEditSheet(initialTitle: "Espresso — Brésil Santa Lúcia") { _ in }
        }
}
