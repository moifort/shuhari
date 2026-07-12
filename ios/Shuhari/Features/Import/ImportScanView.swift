import PhotosUI
import SwiftUI

/// Camera-first recipe import, presented full-screen from the "Importer" tab.
/// Opens straight on the live camera; a photo can also be picked from the
/// library or the recipe typed in (a pasted link is routed to the AI web
/// search). Capture/pick/type → AI analysis → editable preview → createRecipe.
/// On success it hands the new recipe id back via `onCreated` and dismisses.
struct ImportScanView: View {
    let onCreated: (String, RecipeType) -> Void

    private enum Step: Equatable {
        case camera
        case analyzing
        case preview(ImportAnalysis)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .camera
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shouldCapture = false
    @State private var showTextEntry = false
    @State private var rawText = ""
    @State private var isSaving = false
    @State private var errorPresenter = ErrorPresenter()

    var body: some View {
        Group {
            switch step {
            case .camera:
                cameraScreen
            case .analyzing:
                AnalyzingOverlay(message: "L’IA lit et structure la recette…")
            case .preview(let analysis):
                NavigationStack {
                    ImportPreviewPage(analysis: analysis, isSaving: isSaving) { edited in
                        Task { await save(edited) }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            selectedPhoto = nil
            importFromLibrary(item)
        }
        .sheet(isPresented: $showTextEntry) {
            textEntrySheet
                .presentationDetents([.medium, .large])
        }
        .errorAlert(errorPresenter)
    }

    // MARK: - Camera screen

    private var cameraScreen: some View {
        let cameraAvailable = CameraView.isAvailable
        return ZStack {
            if cameraAvailable {
                CameraView(onCapture: { data in capture(data) }, shouldCapture: $shouldCapture)
                    .ignoresSafeArea()
                ViewfinderOverlay()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 8) {
                    Image(systemName: "camera.badge.ellipsis").font(.largeTitle)
                    Text("Caméra indisponible").font(.headline)
                    Text("Choisis une image ou saisis la recette.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding()
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        CircleIcon(systemImage: "xmark", size: 44)
                    }
                    .accessibilityIdentifier("scan-close-button")
                    .accessibilityLabel("Fermer")
                    Spacer()
                }
                .padding()
                Spacer()
            }

            VStack {
                Spacer()
                GlassEffectContainer {
                    HStack {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            CircleIcon(systemImage: "photo", size: 56)
                        }
                        .accessibilityIdentifier("import-library-picker")
                        .accessibilityLabel("Choisir dans la bibliothèque")

                        Spacer()

                        if cameraAvailable {
                            Button { shouldCapture = true } label: {
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .frame(width: 72, height: 72)
                                    .overlay(Circle().fill(.white).frame(width: 60, height: 60))
                            }
                            .accessibilityIdentifier("import-camera-shutter")
                            .accessibilityLabel("Prendre une photo")
                        } else {
                            Color.clear.frame(width: 72, height: 72)
                        }

                        Spacer()

                        Button { showTextEntry = true } label: {
                            CircleIcon(systemImage: "text.cursor", size: 56)
                        }
                        .accessibilityIdentifier("import-text-button")
                        .accessibilityLabel("Saisir la recette")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Text entry

    private var textEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("200 g de spaghetti, 100 g de pecorino… ou colle un lien", text: $rawText, axis: .vertical)
                        .lineLimit(6...12)
                        .accessibilityIdentifier("import-text-field")
                } footer: {
                    Text("Colle ou dicte ta recette. Un lien vers une page web est aussi accepté.")
                }
            }
            .navigationTitle("Saisir la recette")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showTextEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitText()
                    } label: {
                        Label("Analyser", systemImage: "sparkles")
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("analyze-button")
                }
            }
        }
    }

    private func submitText() {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        showTextEntry = false
        let source: ImportAPI.Source = isLink(trimmed) ? .url(trimmed) : .text(trimmed)
        step = .analyzing
        Task { await analyze(source) }
    }

    private func isLink(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false
        else { return false }
        return true
    }

    // MARK: - Actions

    private func capture(_ data: Data) {
        step = .analyzing
        Task {
            let base64 = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.jpegBase64()
            }.value
            guard let base64 else {
                errorPresenter.message = "Impossible de lire la photo prise."
                step = .camera
                return
            }
            await analyze(.photos([base64]))
        }
    }

    private func importFromLibrary(_ item: PhotosPickerItem) {
        step = .analyzing
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                errorPresenter.message = "Impossible de lire l’image sélectionnée."
                step = .camera
                return
            }
            let base64 = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.jpegBase64()
            }.value
            guard let base64 else {
                errorPresenter.message = "Impossible de lire l’image sélectionnée."
                step = .camera
                return
            }
            await analyze(.photos([base64]))
        }
    }

    private func analyze(_ source: ImportAPI.Source) async {
        do {
            let analysis = try await ImportAPI.analyze(source)
            step = .preview(analysis)
        } catch {
            errorPresenter.message = reportError(error)
            step = .camera
        }
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

/// A white SF Symbol on a clear interactive glass circle — the iOS 26 idiom for
/// controls floating over a live media feed.
private struct CircleIcon: View {
    let systemImage: String
    let size: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .glassEffect(.clear.interactive(), in: .circle)
    }
}

#Preview {
    ImportScanView { _, _ in }
}
