import SwiftUI

/// The recipe fiche: header, optional pending-proposal and "à tester" banners,
/// the current version, the trial journal and linked variations. Navigation and
/// mutations are owned by `RecipeDetailView`.
struct RecipeDetailPage: View {
    let recipe: Recipe
    let onExecute: (Int) -> Void

    var body: some View {
        List {
            header

            if let proposal = recipe.pendingProposal {
                pendingProposalSection(proposal)
            }

            if let toTest = recipe.toTest {
                Section {
                    TestBanner(
                        title: nil,
                        versionNumber: toTest.number,
                        change: toTest.change,
                        why: toTest.why ?? toTest.originDetail,
                        type: recipe.type,
                        onExecute: { onExecute(toTest.number) }
                    )
                }
            }

            if let current = recipe.currentVersion {
                CurrentVersionSection(version: current, onExecute: { onExecute(current.number) })
            }

            TrialJournalSection(recipeTitle: recipe.title, trials: recipe.trials)

            VariationsSection(variations: recipe.variations)
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationSubtitle(recipe.subtitle ?? "")
    }

    // MARK: - Header

    private var header: some View {
        Section {
            if let derived = recipe.derivedFrom {
                NavigationLink(value: RecipeRoute.recipe(id: derived.id)) {
                    Label("Dérivée de \(derived.title)", systemImage: "link")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            TypeChip(type: recipe.type)
                .textCase(nil)
        } footer: {
            if let average = recipe.overallAverageNote {
                Text("Note moyenne \(NoteFormat.average(average)) · \(recipe.trials.count) essai\(recipe.trials.count > 1 ? "s" : "")")
            }
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
            .accessibilityIdentifier("pending-proposal-banner")
        }
    }
}
