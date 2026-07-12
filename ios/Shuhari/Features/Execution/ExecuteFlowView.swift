import SwiftUI

/// The full-screen execution flow: execute → capture → record → (promotion sheet
/// or AI proposal). Presented as a `fullScreenCover`; on completion it dismisses
/// and asks the caller to refresh.
struct ExecuteFlowView: View {
    let request: ExecutionRequest
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var replayTrial: Trial?
    @State private var loadError: String?

    @State private var path: [Step] = []
    @State private var isSaving = false
    @State private var analyzing = false
    @State private var showPromotion = false
    @State private var isPromoting = false
    @State private var lastNote = 0
    @State private var errorPresenter = ErrorPresenter()

    private enum Step: Hashable { case capture, proposal }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let recipe, let version = recipe.version(request.versionNumber) {
                    ExecutePage(
                        recipeTitle: recipe.title,
                        version: version,
                        replayParams: replayTrial?.realParams,
                        replayDate: replayTrial?.executedAt,
                        onDone: { path.append(.capture) }
                    )
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
                    Button("Fermer") { finish() }
                }
            }
        }
        .task { await load() }
        .overlay { if analyzing { AnalyzingOverlay(message: "L’IA analyse tes remarques…") } }
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
            CapturePage(
                recipeTitle: recipe.title,
                targets: version.params,
                isSaving: isSaving
            ) { note, remarks, realParams, photo in
                Task { await save(note: note, remarks: remarks, realParams: realParams, photo: photo) }
            }
        case .proposal:
            ProposalView(recipeId: request.recipeId) { finish() }
        }
    }

    // MARK: - Actions

    private func load() async {
        guard recipe == nil else { return }
        do {
            if let trialId = request.replayTrialId {
                replayTrial = try await RecipeAPI.getTrial(id: trialId)
            }
            recipe = try await RecipeAPI.getRecipe(id: request.recipeId)
        } catch {
            loadError = reportError(error)
        }
    }

    private func save(note: Int, remarks: String, realParams: [Param], photo: String?) async {
        isSaving = true
        lastNote = note
        do {
            let result = try await ExecutionAPI.recordTrial(
                recipeId: request.recipeId,
                versionNumber: request.versionNumber,
                note: note,
                remarks: remarks,
                realParams: realParams,
                photoBase64: photo
            )
            isSaving = false
            if result.promotionSuggested {
                showPromotion = true
            } else if note < 8 {
                analyzing = true
                defer { analyzing = false }
                _ = try await ExecutionAPI.requestProposal(recipeId: request.recipeId)
                path.append(.proposal)
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
