import SwiftUI

/// The recipe fiche: header, optional pending-proposal and "à tester" banners,
/// the current version, the trial journal and linked variations. Navigation and
/// mutations are owned by `RecipeDetailView`.
struct RecipeDetailPage: View {
    let recipe: Recipe
    let onExecute: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let proposal = recipe.pendingProposal {
                    pendingProposalBanner(proposal)
                }

                if let toTest = recipe.toTest {
                    TestBanner(
                        title: nil,
                        versionNumber: toTest.number,
                        change: toTest.change,
                        why: toTest.why ?? toTest.originDetail,
                        type: recipe.type,
                        onExecute: { onExecute(toTest.number) }
                    )
                }

                if let current = recipe.currentVersion {
                    CurrentVersionSection(version: current, onExecute: { onExecute(current.number) })
                }

                TrialJournalSection(recipeTitle: recipe.title, trials: recipe.trials)

                VariationsSection(variations: recipe.variations)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            TypeChip(type: recipe.type)
            Text(recipe.title)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = recipe.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let derived = recipe.derivedFrom {
                NavigationLink(value: RecipeRoute.recipe(id: derived.id)) {
                    Label("Dérivée de \(derived.title)", systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(Color(.separator)))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            if let average = recipe.overallAverageNote {
                Text("Note moyenne \(String(format: "%.1f/10", average).replacingOccurrences(of: ".", with: ",")) · \(recipe.trials.count) essai\(recipe.trials.count > 1 ? "s" : "")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pending proposal

    private func pendingProposalBanner(_ proposal: Proposal) -> some View {
        NavigationLink(value: RecipeRoute.proposal(recipeId: recipe.id)) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Proposition de l’IA en attente", systemImage: "flask.fill")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.orange)
                Text(proposal.rationale)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Voir la proposition")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pending-proposal-banner")
    }
}
