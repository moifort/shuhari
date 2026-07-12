import PhotosUI
import SwiftUI

/// Root of the "Importer" tab. Segmented source (Photos / Caméra / URL / Texte), an AI
/// analysis overlay, then the editable preview → createRecipe → recipe fiche.
struct ImportView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case photo, camera, url, text
        var id: String { rawValue }
        var label: String {
            switch self {
            case .photo: "Photos"
            case .camera: "Caméra"
            case .url: "URL"
            case .text: "Texte"
            }
        }
    }

    @State private var path = NavigationPath()
    @State private var mode: Mode = .photo
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var urlText = ""
    @State private var rawText = ""
    @State private var isAnalyzing = false
    @State private var isSaving = false
    @State private var execution: ExecutionRequest?
    @State private var errorPresenter = ErrorPresenter()

    var body: some View {
        NavigationStack(path: $path) {
            form
                .navigationTitle("Importer")
                .navigationDestination(for: ImportAnalysis.self) { analysis in
                    ImportPreviewPage(analysis: analysis, isSaving: isSaving) { edited in
                        Task { await save(edited) }
                    }
                }
                .recipeFlow(path: $path, execution: $execution) {
                    reset()
                }
        }
        .overlay { if isAnalyzing { AnalyzingOverlay(message: "L’IA lit et structure la recette…") } }
        .errorAlert(errorPresenter)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in capturedImage = image }
                .ignoresSafeArea()
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Source", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("import-mode-picker")
            } footer: {
                Text("Photos, caméra, lien ou texte — l’IA structure la recette, tu relis, tu enregistres.")
            }

            sourceSection
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await analyze() }
            } label: {
                Label("Analyser avec l’IA", systemImage: "flask.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!canAnalyze || isAnalyzing)
            .accessibilityIdentifier("analyze-button")
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        switch mode {
        case .photo:
            Section {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images) {
                    Label {
                        Text(photoItems.isEmpty ? "Ajouter des photos" : "\(photoItems.count) photo(s) sélectionnée(s)")
                    } icon: {
                        Image(systemName: photoItems.isEmpty ? "photo.badge.plus" : "checkmark.circle.fill")
                            .foregroundStyle(photoItems.isEmpty ? Color.accentColor : .green)
                    }
                }
                .accessibilityIdentifier("import-photos-picker")
            } footer: {
                Text("Page de livre, sachet, capture d’écran…")
            }
        case .camera:
            Section {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("import-captured-preview")
                        Button {
                            showCamera = true
                        } label: {
                            Label("Reprendre la photo", systemImage: "arrow.triangle.2.circlepath.camera")
                        }
                        .accessibilityIdentifier("import-camera-retake")
                    } else {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Prendre une photo", systemImage: "camera.fill")
                        }
                        .accessibilityIdentifier("import-camera-button")
                    }
                } else {
                    Label("Caméra indisponible sur cet appareil", systemImage: "camera.badge.ellipsis")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Photographie une page de recette, l’IA la structure.")
            }
        case .url:
            Section("Adresse de la recette") {
                TextField("https://…", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("import-url-field")
            }
        case .text:
            Section("Colle ou dicte ta recette") {
                TextField("200 g de spaghetti, 100 g de pecorino…", text: $rawText, axis: .vertical)
                    .lineLimit(6...12)
                    .accessibilityIdentifier("import-text-field")
            }
        }
    }

    // MARK: - State

    private var canAnalyze: Bool {
        switch mode {
        case .photo: return !photoItems.isEmpty
        case .camera: return capturedImage != nil
        case .url: return !urlText.trimmingCharacters(in: .whitespaces).isEmpty
        case .text: return !rawText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func reset() {
        photoItems = []
        capturedImage = nil
        urlText = ""
        rawText = ""
        mode = .photo
    }

    // MARK: - Actions

    private func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let source: ImportAPI.Source
            switch mode {
            case .photo:
                let encoded = await encodePhotos()
                guard !encoded.isEmpty else {
                    errorPresenter.message = "Impossible de lire les photos sélectionnées."
                    return
                }
                source = .photos(encoded)
            case .camera:
                let base64 = await Task.detached(priority: .userInitiated) { [capturedImage] in
                    capturedImage?.jpegBase64()
                }.value
                guard let base64 else {
                    errorPresenter.message = "Impossible de lire la photo prise."
                    return
                }
                source = .photos([base64])
            case .url:
                source = .url(urlText.trimmingCharacters(in: .whitespaces))
            case .text:
                source = .text(rawText)
            }
            let analysis = try await ImportAPI.analyze(source)
            path.append(analysis)
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    private func save(_ analysis: ImportAnalysis) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let recipeId = try await ImportAPI.create(analysis)
            path = NavigationPath()
            path.append(RecipeRoute.recipe(id: recipeId))
        } catch {
            errorPresenter.message = reportError(error)
        }
    }

    private func encodePhotos() async -> [String] {
        var result: [String] = []
        for item in photoItems {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let base64 = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.jpegBase64()
            }.value
            if let base64 { result.append(base64) }
        }
        return result
    }
}

#Preview {
    ImportView()
}
