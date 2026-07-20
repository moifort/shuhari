import SwiftUI

/// The tips flow: write the tips you want to add → the AI rewords them and merges
/// them into the version's own → accept. Presented as a half-screen sheet from the
/// recipe sheet's lightbulb CTA, growing to `.large` for the proposal.
///
/// No version is ever created here: accepting rewrites the displayed version's tips
/// in place. Closing at any point saves nothing.
struct TipsFlowView: View {
    let recipeId: String
    /// The version whose tips are being extended — the one the recipe sheet shows.
    let version: RecipeVersion
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var requested = ""
    @State private var path: [Step] = []
    @State private var detent: PresentationDetent = .medium
    @State private var analyzing = false
    @State private var isSaving = false
    @State private var errorPresenter = ErrorPresenter()
    /// The ephemeral merged list, held in memory while the `.proposal` step is shown.
    @State private var proposedTips: [String] = []

    private enum Step: Hashable { case proposal }

    var body: some View {
        NavigationStack(path: $path) {
            requestPage
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
                            Task { await requestTips() }
                        } label: {
                            ActionIcon(systemImage: "checkmark", isRunning: analyzing)
                        }
                        .disabled(trimmedRequest.isEmpty || analyzing)
                        .accessibilityIdentifier("request-tips-button")
                        .accessibilityLabel("Demander une proposition")
                    }
                }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .overlay { if analyzing { AIThinkingCard(message: "L’IA met en forme vos conseils…") } }
        .errorAlert(errorPresenter)
    }

    private var requestPage: some View {
        Form {
            Section {
                TextField(
                    "Ex. : servir avec du riz, se congèle bien, sortir du frigo 1 h avant…",
                    text: $requested,
                    axis: .vertical
                )
                .lineLimit(8...20)
                .frame(minHeight: 140, alignment: .top)
                .accessibilityIdentifier("tips-field")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Conseils")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var proposalPage: some View {
        TipsProposalPage(
            proposedTips: proposedTips,
            baseTips: version.tips,
            isWorking: isSaving,
            onClose: { dismiss() },
            onValidate: { edited in Task { await save(edited) } }
        )
    }

    private var trimmedRequest: String {
        requested.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestTips() async {
        // Grow first so the Siri loader fills the sheet.
        detent = .large
        analyzing = true
        defer { analyzing = false }
        do {
            proposedTips = try await ProposalAPI.requestTips(
                recipeId: recipeId,
                versionNumber: version.number,
                tips: trimmedRequest
            )
            path.append(.proposal)
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    /// Accepting replaces the displayed version's tips — no version is created.
    private func save(_ tips: [String]) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await ProposalAPI.updateTips(
                recipeId: recipeId,
                versionNumber: version.number,
                tips: tips
            )
            onFinished()
            dismiss()
        } catch {
            errorPresenter.message = reportError(error)
        }
    }
}

#if DEBUG
#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TipsFlowView(
                recipeId: Fixtures.bourguignon.id,
                version: Fixtures.bourguignonV4,
                onFinished: {}
            )
        }
}
#endif
