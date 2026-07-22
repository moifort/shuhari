import SwiftUI

/// The edit sheet for a recipe's cautions: one text field per warning, swipe to
/// delete, a row to add one. Saving hands back the complete list (blank rows
/// dropped) — full-replacement semantics, an emptied list clears the banner.
struct WarningsEditSheet: View {
    let initialWarnings: [String]
    let onSave: (_ warnings: [String]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [Draft]
    @State private var error = ErrorPresenter()
    @FocusState private var focusedDraft: UUID?

    /// An editable row. The stable identity keeps SwiftUI's rows (and the focus)
    /// honest while the cook inserts and deletes around them.
    private struct Draft: Identifiable {
        let id = UUID()
        var text: String
    }

    init(
        initialWarnings: [String],
        onSave: @escaping (_ warnings: [String]) async throws -> Void
    ) {
        self.initialWarnings = initialWarnings
        self.onSave = onSave
        // An empty list opens ready to type — the sheet was summoned to add one.
        let drafts = initialWarnings.isEmpty ? [Draft(text: "")] : initialWarnings.map(Draft.init)
        self._drafts = State(initialValue: drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($drafts) { $draft in
                        TextField("Attention à…", text: $draft.text, axis: .vertical)
                            .focused($focusedDraft, equals: draft.id)
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }
                    Button("Ajouter un avertissement", systemImage: "plus") {
                        let draft = Draft(text: "")
                        drafts.append(draft)
                        focusedDraft = draft.id
                    }
                    .accessibilityIdentifier("add-warning-row-button")
                } footer: {
                    Text("Affichés en bannière en haut de la recette. Glisser pour supprimer.")
                }
            }
            .navigationTitle("Avertissements")
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
                                try await onSave(warnings)
                            } onSuccess: { dismiss() }
                        }
                    } label: {
                        ActionIcon(systemImage: "checkmark", isRunning: error.isRunning)
                    }
                    .disabled(error.isRunning)
                    .accessibilityIdentifier("save-warnings-button")
                    .accessibilityLabel("Enregistrer")
                }
            }
            .errorAlert(error)
        }
        // A swipe while the edit is being written would orphan the task.
        .interactiveDismissDisabled(error.isRunning)
    }

    /// The complete list to save: trimmed, blank rows dropped.
    private var warnings: [String] {
        drafts
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview("Avec avertissements") {
    Text("Fond")
        .sheet(isPresented: .constant(true)) {
            WarningsEditSheet(
                initialWarnings: ["Le fouet doit être mis dès le début."]
            ) { _ in }
        }
}

#Preview("Vide — prêt à saisir") {
    Text("Fond")
        .sheet(isPresented: .constant(true)) {
            WarningsEditSheet(initialWarnings: []) { _ in }
        }
}
