import SwiftUI

/// The execution flow: execute → capture → record → next step. A written remark
/// asks the AI for the next version to try; otherwise a high-scoring trial on the
/// pending version offers promotion, and everything else just finishes. Presented
/// as a `fullScreenCover` (`.cover`) from Home/replay, or as a half-screen `.sheet`
/// from the fiche's record CTA; on completion it dismisses and asks the caller to
/// refresh.
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
    @State private var showPromotion = false
    @State private var isPromoting = false
    @State private var lastNote = 0
    @State private var detent: PresentationDetent = .medium
    @State private var errorPresenter = ErrorPresenter()

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
                            // The fiche already shows the recipe: go straight to the
                            // trial capture instead of re-displaying the version.
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
        .sheet(isPresented: $showPromotion) {
            PromotionSheet(
                recipeTitle: recipe?.title ?? "",
                versionNumber: request.versionNumber,
                note: lastNote,
                isWorking: isPromoting,
                onPromote: { Task { await promote() } },
                onLater: { showPromotion = false; finish() }
            )
        }
        .errorAlert(errorPresenter)
    }

    @ViewBuilder
    private func destination(_ step: Step, recipe: Recipe, version: RecipeVersion) -> some View {
        switch step {
        case .capture:
            captureScreen(recipe: recipe, version: version)
        case .proposal:
            ProposalView(recipeId: request.recipeId) { finish() }
        }
    }

    private func captureScreen(recipe: Recipe, version: RecipeVersion) -> some View {
        CapturePage(isSaving: isSaving) { note, remarks, photo in
            Task { await save(note: note, remarks: remarks, photo: photo) }
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

    private func save(note: Int, remarks: String, photo: String?) async {
        isSaving = true
        lastNote = note
        // A written remark is the request to iterate; blank input stays a dash
        // in the journal but skips the AI.
        let hasRemarks = !remarks.isEmpty
        do {
            let result = try await ExecutionAPI.recordTrial(
                recipeId: request.recipeId,
                versionNumber: request.versionNumber,
                note: note,
                remarks: hasRemarks ? remarks : "—",
                photoBase64: photo
            )
            isSaving = false
            if hasRemarks {
                // Remarks written → let the AI draft the next version to try,
                // whatever the note. Grow first so the Siri loader fills the sheet.
                detent = .large
                analyzing = true
                defer { analyzing = false }
                _ = try await ExecutionAPI.requestProposal(recipeId: request.recipeId)
                path.append(.proposal)
            } else if result.promotionSuggested {
                detent = .large
                showPromotion = true
            } else {
                finish()
            }
        } catch {
            isSaving = false
            analyzing = false
            errorPresenter.message = reportError(error)
        }
    }

    private func promote() async {
        isPromoting = true
        defer { isPromoting = false }
        do {
            try await RecipeAPI.promoteVersion(recipeId: request.recipeId, versionNumber: request.versionNumber)
            showPromotion = false
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
