import PhotosUI
import SwiftUI

/// What the user handed us to import. Resolved to an `ImportAPI.Source` inside
/// the sheet's task so the sheet can appear *immediately* (showing the AI loader)
/// while a photo is still being read/encoded — nothing lingers over the camera.
enum ImportInput {
    case library(PhotosPickerItem)
    case capture(Data)
    case source(ImportAPI.Source)   // text / link, already resolved
}

struct ImportJob: Identifiable {
    let id = UUID()
    let input: ImportInput
}

/// The opaque sheet presented over the camera: runs the AI analysis (glowing
/// loader), then hands off to the editable `ImportPreviewPage`, and creates the
/// recipe on Valider. Fermer / failure "close" abandons the whole import.
struct ImportReviewSheet: View {
    let input: ImportInput
    /// Success → create the recipe and route the tab (dismisses the whole cover).
    let onCreated: (String, RecipeType) -> Void
    /// Fermer / analysis-failure close → abandon the import and close the flow.
    let onCancel: () -> Void

    private enum Phase: Equatable {
        case analyzing
        case form(ImportAnalysis)
        case failed
    }

    @State private var phase: Phase = .analyzing
    @State private var isSaving = false
    @State private var errorPresenter = ErrorPresenter()

    var body: some View {
        NavigationStack {
            // A stable ZStack root keeps NavigationStack from hard-swapping its
            // root view — the children crossfade instead of hard-cutting when the
            // analysis resolves (loader → form, or → error state).
            ZStack {
                switch phase {
                case .analyzing:
                    analyzingView
                        .transition(.opacity)
                case .form(let analysis):
                    ImportPreviewPage(analysis: analysis, isSaving: isSaving, onCancel: onCancel) { edited in
                        Task { await save(edited) }
                    }
                    .transition(.opacity)
                case .failed:
                    failedView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: phase)
        }
        .errorAlert(errorPresenter)
        // While a recipe is being created, block Fermer and swipe-to-dismiss so a
        // cancel can't orphan the create task (which would still fire onCreated).
        .interactiveDismissDisabled(isSaving)
        .task { await run() }
    }

    // MARK: - Phases

    private var analyzingView: some View {
        AIThinkingCard(message: "Analyse IA…")
            .navigationTitle("Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark") { onCancel() }
                }
            }
    }

    private var failedView: some View {
        ContentUnavailableView {
            Label("Analyse impossible", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Réessaie ou ferme l’import.")
        } actions: {
            Button("Réessayer") { Task { await run() } }
        }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer", systemImage: "xmark") { onCancel() }
            }
        }
    }

    // MARK: - Work

    private func run() async {
        phase = .analyzing
        // Keep the loader on screen long enough to actually see the animation,
        // even when the AI answers almost instantly. Failures skip the wait.
        let minimumShown = Task { try? await Task.sleep(for: .seconds(3.5)) }
        guard let source = await resolveSource() else {
            minimumShown.cancel()
            errorPresenter.message = "Impossible de lire l’image sélectionnée."
            phase = .failed
            return
        }
        do {
            let analysis = try await ImportAPI.analyze(source)
            _ = await minimumShown.value
            phase = .form(analysis)
        } catch {
            minimumShown.cancel()
            errorPresenter.message = reportError(error)
            phase = .failed
        }
    }

    private func resolveSource() async -> ImportAPI.Source? {
        switch input {
        case .source(let source):
            return source
        case .capture(let data):
            return await encode(data)
        case .library(let item):
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return await encode(data)
        }
    }

    private func encode(_ data: Data) async -> ImportAPI.Source? {
        let base64 = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)?.jpegBase64()
        }.value
        return base64.map { .photos([$0]) }
    }

    private func save(_ analysis: ImportAnalysis) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let recipeId = try await ImportAPI.create(analysis)
            onCreated(recipeId, analysis.type)
        } catch {
            errorPresenter.message = reportError(error)
        }
    }
}
