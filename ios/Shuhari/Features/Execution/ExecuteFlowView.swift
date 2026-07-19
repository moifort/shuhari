import SwiftUI

/// The execution flow: execute → capture → record → next step. A written remark
/// asks the AI for the next version to try; a blank remark just records the rating
/// and finishes. Presented as a `fullScreenCover` (`.cover`) from Home/replay, or
/// as a half-screen `.sheet` from the fiche's record CTA; on completion it
/// dismisses and asks the caller to refresh.
struct ExecuteFlowView: View {
    /// How the flow is hosted. `.sheet` sizes the capture at `.medium` and grows to
    /// `.large` for the AI proposition; `.cover` is the full-screen presentation.
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
    /// The ephemeral AI proposition, held in memory while the `.proposition` step is shown.
    @State private var proposition: Proposition?
    @State private var isAcceptingProposition = false

    private enum Step: Hashable { case capture, proposition }

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
        case .proposition:
            if let proposition {
                // The ephemeral AI proposition is already in memory (from `save`);
                // show it directly against the recipe already loaded — no extra
                // fetch. The base is the version it iterates on (`basedOn`).
                let base = recipe.version(proposition.basedOn)
                PropositionPage(
                    type: recipe.type,
                    proposition: proposition,
                    nextVersionNumber: recipe.nextVersionNumber,
                    baseIngredients: base?.ingredients ?? [],
                    baseSteps: base?.steps ?? [],
                    isWorking: isAcceptingProposition,
                    onClose: { finish() },
                    onValidate: { edited in Task { await acceptProposition(edited) } }
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

    private func save(rating: Int, remarks: String, photo: String?) async {
        isSaving = true
        // A written remark is the request to iterate; blank input stays a dash
        // in the journal but skips the AI.
        let hasRemarks = !remarks.isEmpty
        do {
            try await ExecutionAPI.recordAttempt(
                recipeId: request.recipeId,
                versionNumber: request.versionNumber,
                rating: rating,
                remarks: hasRemarks ? remarks : "—",
                photoBase64: photo
            )
            isSaving = false
            if hasRemarks {
                // Remarks written → let the AI propose the next version to try, built
                // on the version just cooked, whatever the rating. Grow first so the
                // Siri loader fills the sheet.
                detent = .large
                analyzing = true
                defer { analyzing = false }
                proposition = try await ExecutionAPI.requestProposition(
                    recipeId: request.recipeId,
                    versionNumber: request.versionNumber
                )
                path.append(.proposition)
            } else {
                finish()
            }
        } catch {
            isSaving = false
            analyzing = false
            errorPresenter.message = reportError(error)
        }
    }

    private func acceptProposition(_ edited: PropositionEdit) async {
        isAcceptingProposition = true
        defer { isAcceptingProposition = false }
        do {
            try await PropositionAPI.accept(recipeId: request.recipeId, proposition: edited)
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
