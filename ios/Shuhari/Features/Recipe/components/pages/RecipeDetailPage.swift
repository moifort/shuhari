import SwiftUI

/// The recipe fiche, iOS Photos style: header badges (type + version), the
/// ingredients and the best-rated version step by step. Attempts live in the
/// history. Navigation and mutations are owned by `RecipeDetailView`.
struct RecipeDetailPage: View {
    let recipe: Recipe
    /// When set, the fiche renders THIS version instead of the best-rated one —
    /// the attempt view. Nil (the default) keeps the fiche strictly unchanged.
    var focusVersion: RecipeVersion? = nil
    /// Ingredient names changed vs the previous version → orange dot.
    var modifiedIngredients: Set<String> = []
    /// Step indices changed vs the previous version → orange dot.
    var modifiedSteps: Set<Int> = []
    /// The change summary and rationale of the focused version, shown in the
    /// orange banner atop an attempt fiche.
    var change: String? = nil
    var why: String? = nil

    /// The version the fiche presents: the focused attempt version when set,
    /// otherwise the recipe's `versionToOpen`.
    private var displayedVersion: RecipeVersion {
        focusVersion ?? recipe.versionToOpen
    }

    var body: some View {
        List {
            banner
            header

            IngredientsSection(ingredients: displayedVersion.ingredients, modified: modifiedIngredients)
            ReferenceVersionSection(version: displayedVersion, modified: modifiedSteps)
        }
        .listSectionSpacing(5)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationBarTitleDisplayMode(.inline)
        // The Photos-style centre pill: recipe title (bold) over its date, same small
        // size, in a glass capsule.
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(recipe.title)
                        .font(.footnote.bold())
                        .lineLimit(1)
                    Text(dateLabel)
                        .font(.footnote)
                        .lineLimit(1)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The recipe's creation date, e.g. "12 juin 2025".
    private var dateLabel: String {
        recipe.createdAt.formatted(.dateTime.day().month(.abbreviated).year())
    }

    // MARK: - Banner

    // The orange attempt banner: the change summary + rationale of the focused
    // version, in an orange-bordered card whose edges align with the section
    // cards below (default insets, only the fill/overlay are customised). Only
    // shown in focus mode with content — nil focus renders nothing.
    @ViewBuilder
    private var banner: some View {
        if focusVersion != nil, change?.isEmpty == false || why?.isEmpty == false {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if let change, !change.isEmpty {
                        Text(change)
                            .font(.title3.weight(.semibold))
                    }
                    if let why, !why.isEmpty {
                        Text(why)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.l)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.Status.attempt.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.Status.attempt, lineWidth: 1))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    // MARK: - Header

    // The badges + rating line: a normal list row, so it scrolls with the page and
    // fades under the soft scroll edge.
    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    RecipeHeaderBadges(
                        type: recipe.type,
                        versionNumber: displayedVersion.number,
                        attemptCount: recipe.attempts.count
                    )
                    Spacer(minLength: Theme.Spacing.s)
                    if let average = recipe.overallAverageRating {
                        RatingStars(rating: average)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: -1, leading: 0, bottom: -1, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

#Preview("Plat — v4 à tester") {
    NavigationStack {
        RecipeDetailPage(recipe: Fixtures.bourguignon)
    }
}

#Preview("Thermomix") {
    NavigationStack {
        RecipeDetailPage(recipe: Fixtures.risotto)
    }
}

#Preview("Essai — v3 focalisée") {
    NavigationStack {
        RecipeDetailPage(
            recipe: Fixtures.bourguignon,
            focusVersion: Fixtures.bourguignonV3,
            modifiedIngredients: ["Vin rouge"],
            modifiedSteps: [],
            change: Fixtures.bourguignonV3.change,
            why: Fixtures.bourguignonV3.why
        )
    }
}
