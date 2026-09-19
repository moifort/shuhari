import SwiftUI

/// Says that this recipe is made of another one, and at what weight. Two steps: pick
/// the recipe from the notebook, then set the weight on its own shopping list — type
/// the quantity wanted on one line ("my flour is 100 g" where it writes 500 g) or walk
/// it with the −/+; either way the whole list follows the proportion.
///
/// The notebook is read from its index — every recipe at once, unpaginated — so the
/// alphabet down the side reaches all of it, not just the first page of the library.
///
/// Linking is not cooking: no version is created and the recipe is not redated. The
/// sheet opens straight on the weight step when a link is being corrected.
struct LinkRecipeSheet: View {
    /// The recipe being edited: never offered to itself.
    let excludedId: String
    /// The recipes already linked — ticked in the list, and relinking one is how its
    /// weight is corrected.
    var linkedIds: Set<String> = []
    /// Set to open straight on the weight step of an existing link.
    var editing: Editing? = nil
    let onLink: (_ recipeId: String, _ scale: Double) async throws -> Void

    /// The link being corrected: which recipe, and the weight it currently holds.
    struct Editing: Identifiable, Hashable {
        let recipeId: String
        let scale: Double
        var id: String { recipeId }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var index: [LibraryIndexEntry]?
    @State private var error = ErrorPresenter()
    @State private var picked: Editing?
    /// The index could not be read: the list gives way to a retry.
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Lier une recette")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                }
                .errorAlert(error)
                .task { await loadIndex() }
                .navigationDestination(item: $picked) { link in
                    WeightStep(recipeId: link.recipeId, scale: link.scale) { scale in
                        try await onLink(link.recipeId, scale)
                        dismiss()
                    }
                }
        }
        // Correcting a weight skips the list entirely: the recipe is already chosen.
        .onAppear { picked = picked ?? editing }
    }

    @ViewBuilder
    private var content: some View {
        if let index {
            LinkCandidateList(
                candidates: index
                    .filter { $0.id != excludedId }
                    .map { LinkCandidateList.Item(id: $0.id, title: $0.title) },
                linkedIds: linkedIds,
                onPick: { picked = Editing(recipeId: $0, scale: 1) }
            )
        } else if loadFailed {
            ContentUnavailableView {
                Label("Carnet indisponible", systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Réessayer") { Task { await loadIndex() } }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadIndex() async {
        loadFailed = false
        await error.run { index = try await LibraryAPI.index(types: RecipeType.cooking) }
        loadFailed = index == nil
    }
}

/// Every recipe the notebook could link, read like a book's index: alphabetical, one
/// section per initial letter with the alphabet down the side, and a search on top.
/// Accents and case are ignored both ways — "creme" finds "Crème", "Éclair" files
/// under E. Primitive-first: ids and titles, no network.
struct LinkCandidateList: View {
    struct Item: Identifiable, Sendable {
        let id: String
        let title: String
    }

    let candidates: [Item]
    var linkedIds: Set<String> = []
    let onPick: (_ recipeId: String) -> Void

    @State private var query = ""

    /// The candidates the search keeps, cut by initial letter; a title that opens on
    /// a digit or a sign files under "#", after Z.
    private var letters: [(letter: String, items: [Item])] {
        let needle = Self.folded(query.trimmingCharacters(in: .whitespaces))
        let kept: [(item: Item, title: String)] = candidates
            .map { (item: $0, title: Self.folded($0.title)) }
            .filter { needle.isEmpty || $0.title.contains(needle) }
            // French collation, so "Bœuf" reads as "Boeuf" and lands before "Brioche".
            .sorted {
                $0.item.title.compare(
                    $1.item.title,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: Self.french
                ) == .orderedAscending
            }
        let grouped: [String: [Item]] = Dictionary(
            grouping: kept.map(\.item)
        ) { Self.initial(of: Self.folded($0.title)) }
        let keys = grouped.keys.sorted { lhs, rhs in
            lhs == "#" || rhs == "#" ? rhs == "#" && lhs != "#" : lhs < rhs
        }
        return keys.map { letter in (letter: letter, items: grouped[letter] ?? []) }
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private static let french = Locale(identifier: "fr_FR")

    /// The ligatures are filed under their first letter, as a dictionary does.
    private static func initial(of foldedTitle: String) -> String {
        guard let first = foldedTitle.first, first.isLetter else { return "#" }
        switch first {
        case "œ": return "O"
        case "æ": return "A"
        default: return String(first).uppercased()
        }
    }

    var body: some View {
        let letters = letters
        List {
            if candidates.isEmpty {
                ContentUnavailableView(
                    "Aucune autre recette",
                    systemImage: "book",
                    description: Text("Importe la recette du poolish d’abord.")
                )
            } else if letters.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(letters, id: \.letter) { group in
                Section(group.letter) {
                    ForEach(group.items) { item in
                        Button {
                            onPick(item.id)
                        } label: {
                            row(item)
                        }
                        .accessibilityIdentifier("link-candidate-\(item.id)")
                    }
                }
                .sectionIndexLabel(group.letter)
            }
        }
        .listSectionIndexVisibility(.visible)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Rechercher une recette"
        )
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            // A button tints its label; a title to pick is still read as text.
            Text(item.title)
                .foregroundStyle(Color.primary)
            Spacer(minLength: Theme.Spacing.s)
            if linkedIds.contains(item.id) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        // The whole width answers the tap, not just the title.
        .contentShape(Rectangle())
    }
}

/// The weight step: the linked recipe's own shopping list, shown at the weight being
/// set. Loads that recipe (its best version is what answers for it) and hands the
/// factor to `LinkWeightForm`, which knows nothing of the network.
private struct WeightStep: View {
    let recipeId: String
    let scale: Double
    let onConfirm: (_ scale: Double) async throws -> Void

    @State private var recipe: Recipe?
    @State private var error = ErrorPresenter()

    var body: some View {
        Group {
            if let recipe {
                LinkWeightForm(
                    title: recipe.title,
                    ingredients: recipe.versionToOpen.ingredients.map { ($0.name, $0.quantity) },
                    initialScale: scale,
                    isLinking: error.isRunning,
                    onConfirm: { chosen in
                        Task { await error.run { try await onConfirm(chosen) } }
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .errorAlert(error)
        .task {
            await error.run { recipe = try await RecipeAPI.getRecipe(id: recipeId) }
        }
    }
}

/// How much of a recipe goes in, set on its own shopping list: type the quantity
/// wanted on any line, or walk it with the −/+. Every other line follows the same
/// proportion — the list is what the cook reads, the factor is only what is stored.
/// Primitive-first: `(name, quantity)` pairs, no domain struct, no network.
struct LinkWeightForm: View {
    let title: String
    let ingredients: [(name: String, quantity: String)]
    let initialScale: Double
    /// A CTA that hits the network shows it.
    var isLinking: Bool = false
    let onConfirm: (_ scale: Double) -> Void

    @State private var scale: Double
    /// Every line as it currently reads. Held rather than derived at each draw: a
    /// field the cook is typing into cannot be rewritten under their fingers, and
    /// each of them is rewritten whole the moment the weight moves.
    @State private var texts: [String]
    @FocusState private var focused: Int?

    init(
        title: String,
        ingredients: [(name: String, quantity: String)],
        initialScale: Double,
        isLinking: Bool = false,
        onConfirm: @escaping (_ scale: Double) -> Void
    ) {
        self.title = title
        self.ingredients = ingredients
        self.initialScale = initialScale
        self.isLinking = isLinking
        self.onConfirm = onConfirm
        self._scale = State(initialValue: initialScale)
        self._texts = State(
            initialValue: ingredients.map { QuantityScaling.scaled($0.quantity, by: initialScale) }
        )
    }

    private var scalableRows: Set<Int> {
        Set(ingredients.indices.filter { QuantityScaling.isScalable(ingredients[$0].quantity) })
    }

    var body: some View {
        List {
            Section {
                if ingredients.isEmpty {
                    Text("Aucun ingrédient")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { index, item in
                        row(index: index, item: item)
                    }
                }
            } header: {
                HStack {
                    Text("Quantités utilisées ici")
                    Spacer()
                    if scale != 1 {
                        Text(QuantityScaling.factorLabel(scale))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Status.changed)
                        Button("Réinitialiser") { reset() }
                            .font(.footnote)
                            .accessibilityIdentifier("link-weight-reset")
                    }
                }
            } footer: {
                Text("Écris la quantité voulue sur une ligne : tout le reste suit la proportion.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    focused = nil
                    onConfirm(scale)
                } label: {
                    if isLinking {
                        ProgressView()
                    } else {
                        Text("Lier")
                    }
                }
                .disabled(isLinking)
                .accessibilityIdentifier("confirm-link")
            }
        }
        // Leaving a line is what reads what was typed into it — there is no "OK" on
        // a quantity, and the −/+ of another line count as leaving.
        .onChange(of: focused) { previous, _ in
            if let previous { commit(previous) }
        }
    }

    @ViewBuilder
    private func row(index: Int, item: (name: String, quantity: String)) -> some View {
        if scalableRows.contains(index) {
            // The field and the −/+ are siblings, never nested: a text field inside a
            // stepper's label fights it for the tap, and the quantity is what the cook
            // aims at first.
            HStack(spacing: Theme.Spacing.s) {
                Text(item.name)
                Spacer(minLength: Theme.Spacing.s)
                TextField("", text: $texts[index])
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .foregroundStyle(scale == 1 ? Color.primary : Theme.Status.changed)
                    .focused($focused, equals: index)
                    .submitLabel(.done)
                    .onSubmit { focused = nil }
                    .frame(maxWidth: 110)
                    .accessibilityIdentifier("link-quantity-\(index)")
                Stepper("", onIncrement: { step(index, 1) }, onDecrement: { step(index, -1) })
                    .labelsHidden()
                    .accessibilityIdentifier("link-stepper-\(index)")
            }
        } else {
            // Nothing to multiply here ("Sel", "Quelques brins"): the line reads as
            // written, whatever the weight.
            LabeledContent(item.name) {
                Text(item.quantity)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// What was typed on that line becomes the weight of the whole list. A quantity
    /// the line cannot be read as (another unit, a word) leaves the weight where it
    /// was, and rewriting the lines puts the refused one back to what it showed.
    private func commit(_ index: Int) {
        rescale(
            to: QuantityScaling.factor(from: ingredients[index].quantity, to: texts[index]) ?? scale
        )
    }

    private func step(_ index: Int, _ direction: Int) {
        // A quantity being typed is read before the tick moves anything: the tick
        // starts from what the cook wrote, not from what it replaced.
        if let focused { commit(focused) }
        focused = nil
        guard
            let next = QuantityScaling.factorAfterStep(
                on: ingredients[index].quantity,
                from: scale,
                direction: direction
            )
        else { return }
        rescale(to: next)
    }

    private func reset() {
        focused = nil
        rescale(to: 1)
    }

    /// The single way the weight moves: one factor, and every line rewritten from it.
    private func rescale(to next: Double) {
        scale = next
        texts = ingredients.map { QuantityScaling.scaled($0.quantity, by: next) }
    }
}

#if DEBUG
#Preview("Choisir la recette") {
    NavigationStack {
        LinkCandidateList(
            candidates: LinkCandidateList.Item.samples,
            linkedIds: ["poolish"],
            onPick: { _ in }
        )
        .navigationTitle("Lier une recette")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension LinkCandidateList.Item {
    static let samples: [Self] = [
        "Poolish", "Pâte brisée", "Crème pâtissière", "Éclair au café", "Bœuf bourguignon",
        "Ravioli ricotta", "Sauce tomate", "Levain", "Fond brun", "Ganache", "Beurre noisette",
        "Crème anglaise", "Pâte à choux", "Mayonnaise", "Vinaigrette", "Tarte au citron",
        "Brioche", "Gnocchi", "Aïoli", "Jus de veau", "Nage de légumes", "Oignons confits",
        "Quiche lorraine", "Risotto", "Ubriaco", "Zeste confit", "7 épices",
    ].map { Self(id: $0 == "Poolish" ? "poolish" : $0, title: $0) }
}

#Preview("Le poids — telle qu’elle est écrite") {
    NavigationStack {
        LinkWeightForm(
            title: "Poolish",
            ingredients: [
                ("Farine T65", "500 g"),
                ("Eau", "500 ml"),
                ("Levure fraîche", "1 g"),
                ("Sel", "à goût"),
            ],
            initialScale: 1,
            onConfirm: { _ in }
        )
    }
}

#Preview("Le poids — un cinquième") {
    NavigationStack {
        LinkWeightForm(
            title: "Poolish",
            ingredients: [
                ("Farine T65", "500 g"),
                ("Eau", "500 ml"),
                ("Levure fraîche", "1 g"),
            ],
            initialScale: 0.2,
            onConfirm: { _ in }
        )
    }
}
#endif
