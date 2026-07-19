import SwiftUI

/// The execution flow: execute → capture → record → next step.
///
/// Where the cook lands depends on the remark. A blank remark asks for nothing: the
/// rating (and photo) is recorded on the version cooked, and the flow ends. A written
/// remark asks the AI for the next version to try, and the cook goes with it — it is
/// recorded on the version the accepted proposal creates, leaving the version cooked
/// untouched. Nothing is saved before that: closing the proposal saves nothing.
///
/// Presented as a `fullScreenCover` (`.cover`) from Home/replay, or as a half-screen
/// `.sheet` from the recipe sheet's record CTA; on completion it dismisses and asks
/// the caller to refresh.
struct ExecuteFlowView: View {
    /// How the flow is hosted. `.sheet` sizes the capture at `.medium` and grows to
    /// `.large` for the AI proposal; `.cover` is the full-screen presentation.
    enum Presentation { case cover, sheet }

    let request: ExecutionRequest
    var presentation: Presentation = .cover
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var loadError: String?

    @State private var path: [Step] = []
    @State private var isSaving = false
    @State private var analyzing = false
    @State private var detent: PresentationDetent = .medium
    @State private var errorPresenter = ErrorPresenter()
    /// The ephemeral AI proposal, held in memory while the `.proposal` step is shown.
    @State private var proposal: Proposal?
    /// The cook that asked for that proposal — held here, unwritten, until the
    /// proposal is accepted and it lands on the version it created.
    @State private var pendingAttempt: Attempt?
    @State private var isAcceptingProposal = false

    private enum Step: Hashable { case capture, proposal }

    var body: some View {
        if presentation == .sheet {
            flow
                .presentationDetents([.medium, .large], selection: $detent)
                .presentationDragIndicator(.visible)
        } else {
            flow
        }
    }

    private var flow: some View {
        NavigationStack(path: $path) {
            Group {
                if let recipe, let version = recipe.version(request.versionNumber) {
                    Group {
                        if request.startAtCapture {
                            // The recipe sheet already shows the recipe: go straight to the
                            // attempt capture instead of re-displaying the version.
                            captureScreen(recipe: recipe, version: version)
                        } else {
                            ExecutePage(
                                recipeTitle: recipe.title,
                                version: version,
                                onDone: { path.append(.capture) }
                            )
                        }
                    }
                    .navigationDestination(for: Step.self) { step in
                        destination(step, recipe: recipe, version: version)
                    }
                } else if let loadError {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(loadError))
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { finish() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fermer")
                }
            }
        }
        .task { await load() }
        .overlay { if analyzing { AIThinkingCard(message: "L’IA analyse tes remarques…") } }
        .errorAlert(errorPresenter)
    }

    @ViewBuilder
    private func destination(_ step: Step, recipe: Recipe, version: RecipeVersion) -> some View {
        switch step {
        case .capture:
            captureScreen(recipe: recipe, version: version)
        case .proposal:
            if let proposal {
                // The ephemeral AI proposal is already in memory (from `save`);
                // show it directly against the recipe already loaded — no extra
                // fetch. The base is the version it iterates on (`basedOn`).
                let base = recipe.version(proposal.basedOn)
                ProposalPage(
                    proposal: proposal,
                    nextVersionNumber: recipe.nextVersionNumber,
                    baseIngredients: base?.ingredients ?? [],
                    baseSteps: base?.content.stepsWithSettings ?? [],
                    isWorking: isAcceptingProposal,
                    onClose: { finish() },
                    onValidate: { edited in Task { await acceptProposal(edited) } }
                )
            }
        }
    }

    private func captureScreen(recipe: Recipe, version: RecipeVersion) -> some View {
        CapturePage(isSaving: isSaving) { rating, remarks, photo in
            Task { await save(rating: rating, remarks: remarks, photo: photo) }
        }
    }

    // MARK: - Actions

    private func load() async {
        guard recipe == nil else { return }
        do {
            recipe = try await RecipeAPI.getRecipe(id: request.recipeId)
        } catch {
            loadError = reportError(error)
        }
    }

    // A written remark is the request to iterate: nothing is recorded here, the cook
    // rides along to the proposal and lands on the version it creates. A blank remark
    // is a cook that asks for nothing — it goes straight onto the version cooked.
    private func save(rating: Int, remarks: String, photo: String?) async {
        guard !remarks.isEmpty else {
            await recordBareAttempt(rating: rating, photo: photo)
            return
        }
        pendingAttempt = Attempt(rating: rating, remarks: remarks, photoBase64: photo)
        // Grow first so the Siri loader fills the sheet.
        detent = .large
        analyzing = true
        defer { analyzing = false }
        do {
            proposal = try await ExecutionAPI.requestProposal(
                recipeId: request.recipeId,
                versionNumber: request.versionNumber,
                rating: rating,
                remarks: remarks
            )
            path.append(.proposal)
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    private func recordBareAttempt(rating: Int, photo: String?) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await ExecutionAPI.recordAttempt(
                recipeId: request.recipeId,
                versionNumber: request.versionNumber,
                rating: rating,
                photoBase64: photo
            )
            finish()
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    // Accepting is what writes the cook down: it lands on the version being created,
    // and the version it iterates on stays as it was. Closing the proposal instead
    // records nothing at all.
    private func acceptProposal(_ edited: ProposalEdit) async {
        // Always set: the `.proposal` step is only ever reached through `save` with
        // remarks, which stores the cook before asking the AI.
        guard let pendingAttempt else { return }
        isAcceptingProposal = true
        defer { isAcceptingProposal = false }
        do {
            try await ProposalAPI.accept(
                recipeId: request.recipeId,
                proposal: edited,
                attempt: pendingAttempt
            )
            finish()
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    private func finish() {
        onFinished()
        dismiss()
    }
}
