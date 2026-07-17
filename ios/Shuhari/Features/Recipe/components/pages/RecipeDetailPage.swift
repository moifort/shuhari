import SwiftUI

/// The recipe fiche, iOS Photos style: header badges (type + version), the
/// optional pending-proposal banner, the ingredients and the best-rated version
/// step by step. Trials live in the history. Navigation and mutations are owned
/// by `RecipeDetailView`.
struct RecipeDetailPage: View {
    let recipe: Recipe

    var body: some View {
        List {
            header

            if let proposal = recipe.pendingProposal {
                pendingProposalSection(proposal)
            }

            if let reference = recipe.bestRatedVersion {
                IngredientsSection(ingredients: reference.ingredients)
                ReferenceVersionSection(version: reference)
            }
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

    // MARK: - Header

    // The badges + note line: a normal list row, so it scrolls with the page and
    // fades under the soft scroll edge.
    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    RecipeHeaderBadges(
                        type: recipe.type,
                        versionNumber: recipe.bestRatedVersion?.number,
                        trialCount: recipe.trials.count
                    )
                    Spacer(minLength: Theme.Spacing.s)
                    if let average = recipe.overallAverageNote {
                        NoteStars(note: average)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: -1, leading: 0, bottom: -1, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Pending proposal

    private func pendingProposalSection(_ proposal: Proposal) -> some View {
        Section {
            NavigationLink(value: RecipeRoute.proposal(recipeId: recipe.id)) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Proposition de l’IA en attente", systemImage: "flask.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Status.toTest)
                    Text(proposal.rationale)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pending-proposal-banner")
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
