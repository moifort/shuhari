import PhotosUI
import SwiftUI

/// Camera-first recipe import, presented full-screen from the "Importer" tab.
/// Opens straight on the live camera; a photo can also be picked from the
/// library or the recipe typed in (a pasted link is routed to the AI web
/// search). Capture / pick / type hand the chosen `ImportInput` back via
/// `onPick` and dismiss the camera — the parent then closes this cover and
/// presents the review sheet, so the camera never lingers behind it.
struct ImportScanView: View {
    let onPick: (ImportInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shouldCapture = false
    @State private var showTextEntry = false
    @State private var rawText = ""
    @State private var pendingSource: ImportAPI.Source?

    var body: some View {
        cameraScreen
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                selectedPhoto = nil
                onPick(.library(item))
            }
            .sheet(isPresented: $showTextEntry, onDismiss: startPendingSource) {
                textEntrySheet
                    .presentationDetents([.medium, .large])
            }
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
                    Button("Annuler") {
                        pendingSource = nil
                        showTextEntry = false
                    }
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

    /// Handed off from the text sheet's `onDismiss`: waiting for the text sheet
    /// to fully dismiss before closing the camera avoids a presentation conflict.
    private func startPendingSource() {
        guard let source = pendingSource else { return }
        pendingSource = nil
        onPick(.source(source))
    }

    private func submitText() {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingSource = isLink(trimmed) ? .url(trimmed) : .text(trimmed)
        showTextEntry = false
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

    // MARK: - Capture

    private func capture(_ data: Data) {
        onPick(.capture(data))
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
    ImportScanView { _ in }
}
