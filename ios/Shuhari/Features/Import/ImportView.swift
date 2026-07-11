import PhotosUI
import SwiftUI

/// Root of the "Importer" tab. Segmented source (Photos / URL / Texte), an AI
/// analysis overlay, then the editable preview → createRecipe → recipe fiche.
struct ImportView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case photo, url, text
        var id: String { rawValue }
        var label: String {
            switch self {
            case .photo: "Photos"
            case .url: "URL"
            case .text: "Texte"
            }
        }
    }

    @State private var path = NavigationPath()
    @State private var mode: Mode = .photo
    @State private var photoItems: [PhotosPickerItem] = []
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
        .overlay { if isAnalyzing { analyzingOverlay } }
        .errorAlert(errorPresenter)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nouvelle recette")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                    Text("Importer")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                    Text("Photos, lien ou texte — l’IA structure la recette, tu relis, tu enregistres.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Picker("Source", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("import-mode-picker")

                sourceInput

                Button {
                    Task { await analyze() }
                } label: {
                    Label("Analyser avec l’IA", systemImage: "flask.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canAnalyze || isAnalyzing)
                .accessibilityIdentifier("analyze-button")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var sourceInput: some View {
        switch mode {
        case .photo:
            VStack(alignment: .leading, spacing: 10) {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera").font(.title)
                        Text(photoItems.isEmpty ? "Ajouter des photos" : "\(photoItems.count) photo(s) sélectionnée(s)")
                            .font(.callout.weight(.medium))
                        Text("page de livre, sachet, capture d’écran…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(photoItems.isEmpty ? .secondary : Color.green)
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundStyle(Color(.separator))
                    )
                }
                .accessibilityIdentifier("import-photos-picker")
            }
        case .url:
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Adresse de la recette")
                TextField("https://…", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("import-url-field")
            }
        case .text:
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Colle ou dicte ta recette")
                TextField("200 g de spaghetti, 100 g de pecorino…", text: $rawText, axis: .vertical)
                    .lineLimit(6...12)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("import-text-field")
            }
        }
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text("L’IA lit et structure la recette…")
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    // MARK: - State

    private var canAnalyze: Bool {
        switch mode {
        case .photo: return !photoItems.isEmpty
        case .url: return !urlText.trimmingCharacters(in: .whitespaces).isEmpty
        case .text: return !rawText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func reset() {
        photoItems = []
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
            let jpeg = await Task.detached(priority: .userInitiated) {
                UIImage(data: data).flatMap { $0.resized(maxDimension: 1600).jpegData(compressionQuality: 0.7) }
            }.value
            if let jpeg { result.append(jpeg.base64EncodedString()) }
        }
        return result
    }
}

#Preview {
    ImportView()
}
