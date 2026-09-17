import SwiftUI

/// The tags a recipe is filed under, being corrected. One row per tag: the icon it
/// wears — picked from a menu, "Aucune" being a choice like any other — then its
/// words. Swipe to delete, a row to add one that opens focused. Composes as a
/// `Section` inside a `Form`.
struct TagsEditSection: View {
    @Binding var draft: TagListDraft

    @FocusState private var focused: UUID?

    var body: some View {
        Section {
            ForEach($draft.rows) { $row in
                HStack(spacing: Theme.Spacing.m) {
                    iconMenu($row.icon)
                    TextField("Tag", text: $row.label)
                        .focused($focused, equals: row.id)
                        .submitLabel(.done)
                }
            }
            .onDelete { draft.rows.remove(atOffsets: $0) }
            .onMove { draft.rows.move(fromOffsets: $0, toOffset: $1) }
            if !draft.isFull {
                Button("Ajouter un tag", systemImage: "plus") {
                    draft.add()
                    focused = draft.rows.last?.id
                }
                .accessibilityIdentifier("tag-add")
            }
        } header: {
            Text("Tags")
        } footer: {
            Text("Dans la liste, seule l’icône d’un tag s’affiche : un tag sans icône ne se lit que sur la fiche.")
        }
    }

    // A `Menu` rather than a bare `Picker`, for the reason `IconPicker` gives: the
    // collapsed value of a `Picker` cannot be sized.
    private func iconMenu(_ selection: Binding<TagIcon?>) -> some View {
        Menu {
            Picker("Icône", selection: selection) {
                Label("Aucune", systemImage: "circle.dashed").tag(TagIcon?.none)
                ForEach(TagIcon.allCases) { icon in
                    Label { Text(icon.label) } icon: { icon.iconImage }
                        .tag(TagIcon?.some(icon))
                }
            }
            .pickerStyle(.inline)
        } label: {
            (selection.wrappedValue?.iconImage ?? Image(systemName: "circle.dashed"))
                .foregroundStyle(selection.wrappedValue == nil ? .tertiary : .secondary)
                .frame(width: 28)
        }
        .accessibilityLabel(selection.wrappedValue.map { "Icône \($0.label)" } ?? "Choisir une icône")
    }
}

#if DEBUG
private struct SectionHost: View {
    @State var draft: TagListDraft

    var body: some View {
        Form {
            TagsEditSection(draft: $draft)
        }
    }
}

#Preview("Avec tags") {
    SectionHost(draft: TagListDraft(Fixtures.risotto.tags))
}

#Preview("Vide — prêt à saisir") {
    SectionHost(draft: TagListDraft([]))
}
#endif
