import SwiftUI

/// A version's detail: what it changes and why, its full content (ingredients +
/// steps, each row tinted when it differs from the previous version), and — when
/// the version has been tried — the essai result (photo, note, remarks).
///
/// Diff highlighting mirrors `DraftPage`: a row carries the `Theme.Status.changed`
/// tint whenever it is absent from the previous version (new or modified). The
/// `highlighted` flags are computed by the coordinator (`EssaiDetailView`).
/// Primitive-first — the page receives only primitives and nested `Item` structs.
struct EssaiDetailPage: View {
    /// One ingredient row: name + quantity, tinted when it differs from the
    /// previous version.
    struct IngredientItem: Identifiable {
        let name: String
        let quantity: String
        let highlighted: Bool
        var id: String { name }
    }

    /// One preparation step: its text, optional per-step Thermomix settings, and
    /// whether it differs from the previous version.
    struct StepItem: Identifiable {
        let index: Int
        let text: String
        let time: String?
        let temperature: String?
        let speed: String?
        let reverse: Bool
        let highlighted: Bool
        var id: Int { index }
        var hasSettings: Bool { time != nil || temperature != nil || speed != nil || reverse }
    }

    let recipeTitle: String
    let versionNumber: Int
    /// Date shown in the navigation title for a tried essai.
    let date: Date
    let change: String?
    let why: String?
    let ingredients: [IngredientItem]
    let steps: [StepItem]
    /// Whether the version has been tried (drives the result section's visibility).
    let hasResult: Bool
    let note: Int?
    let remarks: String?
    let photoUrl: String?

    var body: some View {
        List {
            headerSection
            ingredientsSection
            stepsSection
            resultSection
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(navigationTitle)
        .navigationSubtitle("\(recipeTitle) · v\(versionNumber)")
    }

    private var navigationTitle: String {
        hasResult
            ? "Essai du \(date.formatted(.dateTime.day().month(.wide)))"
            : "Version \(versionNumber)"
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        if change?.isEmpty == false || why?.isEmpty == false {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if let change, !change.isEmpty {
                        Text(change)
                            .font(.headline)
                    }
                    if let why, !why.isEmpty {
                        Text(why)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Ingredients

    @ViewBuilder
    private var ingredientsSection: some View {
        if !ingredients.isEmpty {
            Section("Ingrédients") {
                ForEach(ingredients) { item in
                    LabeledContent(item.name) {
                        Text(item.quantity)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .listRowBackground(item.highlighted ? Theme.Status.changed.opacity(0.08) : nil)
                }
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepsSection: some View {
        if !steps.isEmpty {
            Section("Préparation") {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.text)
                                .font(.body)
                            if step.hasSettings {
                                TmxSettingBadges(
                                    time: step.time,
                                    temperature: step.temperature,
                                    speed: step.speed,
                                    reverse: step.reverse
                                )
                            }
                        }
                    }
                    .listRowBackground(step.highlighted ? Theme.Status.changed.opacity(0.08) : nil)
                }
            }
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        if hasResult {
            if let photoUrl, let url = URL(string: photoUrl) {
                Section {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 260)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Photo du résultat")
                }
            }

            Section("Résultat d’essai") {
                HStack(alignment: .top, spacing: 14) {
                    NoteBadge(note: note ?? 0)
                    Text(remarks ?? "")
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

#Preview("Modifié + résultat") {
    NavigationStack {
        EssaiDetailPage(
            recipeTitle: Fixtures.bourguignon.title,
            versionNumber: 3,
            date: Fixtures.date,
            change: "Vin rouge 50 → 75 cl",
            why: "La sauce manquait de corps.",
            ingredients: Fixtures.bourguignonV3.ingredients.map {
                .init(name: $0.name, quantity: $0.quantity, highlighted: $0.name == "Vin rouge")
            },
            steps: Fixtures.bourguignonV3.steps.enumerated().map { index, text in
                .init(index: index, text: text, time: nil, temperature: nil, speed: nil, reverse: false, highlighted: index == 3)
            },
            hasResult: true,
            note: 4,
            remarks: "Sauce nappante, viande fondante.",
            photoUrl: nil
        )
    }
}

#Preview("En attente (sans résultat)") {
    NavigationStack {
        EssaiDetailPage(
            recipeTitle: Fixtures.bourguignon.title,
            versionNumber: 4,
            date: Fixtures.date,
            change: "Cuisson 3 h → 3 h 30",
            why: "Viande encore un peu ferme.",
            ingredients: Fixtures.bourguignonV4.ingredients.map {
                .init(name: $0.name, quantity: $0.quantity, highlighted: false)
            },
            steps: Fixtures.bourguignonV4.steps.enumerated().map { index, text in
                .init(index: index, text: text, time: nil, temperature: nil, speed: nil, reverse: false, highlighted: index == 4)
            },
            hasResult: false,
            note: nil,
            remarks: nil,
            photoUrl: nil
        )
    }
}
