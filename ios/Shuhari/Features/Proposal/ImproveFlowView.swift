import SwiftUI

/// The improvement flow: say what you want changed → the AI proposes the next version
/// → accept it. Presented as a half-screen sheet from the recipe sheet's improve CTA,
/// growing to `.large` for the proposal.
///
/// No cook behind it, so nothing is recorded on the version being improved: the
/// version the accepted proposal creates simply lands on the to-cook list. Closing at
/// any point saves nothing.
struct ImproveFlowView: View {
    let recipeId: String
    /// The version being improved on — the one the recipe sheet is showing.
    let version: RecipeVersion
    let nextVersionNumber: Int
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var improvement = ""
    @State private var path: [Step] = []
    @State private var detent: PresentationDetent = .medium
    @State private var analyzing = false
    @State private var isAccepting = false
    @State private var errorPresenter = ErrorPresenter()
    /// The ephemeral AI proposal, held in memory while the `.proposal` step is shown.
    @State private var proposal: Proposal?

    private enum Step: Hashable { case proposal }

    var body: some View {
        NavigationStack(path: $path) {
            improvementPage
                .navigationDestination(for: Step.self) { _ in proposalPage }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Fermer")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await requestImprovement() }
                        } label: {
                            ActionIcon(systemImage: "checkmark", isRunning: analyzing)
                        }
                        .disabled(trimmedImprovement.isEmpty || analyzing)
                        .accessibilityIdentifier("request-improvement-button")
                        .accessibilityLabel("Demander une proposition")
                    }
                }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .overlay { if analyzing { AIThinkingCard(message: "L’IA imagine la prochaine version…") } }
        .errorAlert(errorPresenter)
    }

    private var improvementPage: some View {
        Form {
            Section {
                TextField(
                    "Ex. : version végétarienne, moins sucré, pour 6 personnes…",
                    text: $improvement,
                    axis: .vertical
                )
                .lineLimit(8...20)
                .frame(minHeight: 140, alignment: .top)
                .accessibilityIdentifier("improvement-field")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Amélioration")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var proposalPage: some View {
        if let proposal {
            ProposalPage(
                proposal: proposal,
                nextVersionNumber: nextVersionNumber,
                baseIngredients: version.ingredients,
                baseSteps: version.content.stepsWithSettings,
                isWorking: isAccepting,
                onClose: { dismiss() },
                onValidate: { edited in Task { await accept(edited) } }
            )
        }
    }

    private var trimmedImprovement: String {
        improvement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestImprovement() async {
        // Grow first so the Siri loader fills the sheet.
        detent = .large
        analyzing = true
        defer { analyzing = false }
        do {
            proposal = try await ProposalAPI.requestImprovement(
                recipeId: recipeId,
                versionNumber: version.number,
                improvement: trimmedImprovement
            )
            path.append(.proposal)
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    /// Accepting creates the version — with no attempt on it, so it is one to test.
    private func accept(_ edited: ProposalEdit) async {
        isAccepting = true
        defer { isAccepting = false }
        do {
            try await ProposalAPI.accept(recipeId: recipeId, proposal: edited, attempt: nil)
            onFinished()
            dismiss()
        } catch {
            errorPresenter.message = reportError(error)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImproveFlowView(
                recipeId: Fixtures.bourguignon.id,
                version: Fixtures.bourguignonV4,
                nextVersionNumber: 5,
                onFinished: {}
            )
        }
}
