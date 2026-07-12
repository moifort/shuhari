import SwiftUI

/// The recipe fiche: header, optional pending-proposal and "à tester" banners,
/// the current version, the trial journal and linked variations. Navigation and
/// mutations are owned by `RecipeDetailView`.
struct RecipeDetailPage: View {
    let recipe: Recipe
    let onExecute: (Int) -> Void

    @ScaledMetric(relativeTo: .title2) private var tileSize: CGFloat = 56

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
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if let current = recipe.currentVersion {
                CurrentVersionSection(version: current, onExecute: { onExecute(current.number) })
            }

            TrialJournalSection(recipeTitle: recipe.title, trials: recipe.trials)

            VariationsSection(variations: recipe.variations)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationSubtitle(recipe.subtitle ?? "")
    }

    // MARK: - Header

    private var header: some View {
        Section {
            HStack(spacing: Theme.Spacing.l) {
                Image(systemName: recipe.type.icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: tileSize, height: tileSize)
                    .background(Color(.systemFill), in: Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TypeChip(type: recipe.type)
                    if let average = recipe.overallAverageNote {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(NoteFormat.bare(average))
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.Status.note(Int(average)))
                            Text("/10")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("· \(recipe.trials.count) essai\(recipe.trials.count > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, Theme.Spacing.xs)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Note moyenne \(NoteFormat.average(average)), \(recipe.trials.count) essais")
                    } else {
                        Text("Pas encore testée")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let derived = recipe.derivedFrom {
                NavigationLink(value: RecipeRoute.recipe(id: derived.id)) {
                    Label("Dérivée de \(derived.title)", systemImage: "link")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pending-proposal-banner")
        }
    }
}

#Preview("Café — v4 à tester") {
    NavigationStack {
        RecipeDetailPage(recipe: Fixtures.espresso, onExecute: { _ in })
    }
}

#Preview("Thermomix") {
    NavigationStack {
        RecipeDetailPage(recipe: Fixtures.risotto, onExecute: { _ in })
    }
}
