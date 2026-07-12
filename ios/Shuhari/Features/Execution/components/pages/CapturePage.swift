import PhotosUI
import SwiftUI

/// Capture what was actually done and tasted: editable real parameters (prefilled
/// with the version targets), a 1–10 note, remarks and an optional photo.
struct CapturePage: View {
    let recipeTitle: String
    let targets: [Param]
    let isSaving: Bool
    let onSave: (_ note: Int, _ remarks: String, _ realParams: [Param], _ photoBase64: String?) -> Void

    @State private var values: [String: String]
    @State private var note: Int?
    @State private var remarks: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoBase64: String?
    @State private var photoAttached = false

    init(
        recipeTitle: String,
        targets: [Param],
        isSaving: Bool,
        onSave: @escaping (_ note: Int, _ remarks: String, _ realParams: [Param], _ photoBase64: String?) -> Void
    ) {
        self.recipeTitle = recipeTitle
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self._values = State(initialValue: Dictionary(uniqueKeysWithValues: targets.map { ($0.key, $0.value) }))
    }

    var body: some View {
        Form {
            Section {
                ForEach(targets) { target in
                    LabeledContent(target.key) {
                        TextField(target.value, text: binding(for: target.key))
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("real-param-\(target.key)")
                    }
                }
            } header: {
                Text("Paramètres réels")
            } footer: {
                Text("Pré-remplis avec les cibles — corrige ce qui a réellement changé.")
            }

            Section("Note") {
                NotePicker(selection: $note)
            }

            Section("Remarques") {
                TextField("Ex. : trop amer, coule trop vite, manque de liant…", text: $remarks, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("remarks-field")
            }

            Section("Photo du résultat") {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label {
                        Text(photoAttached ? "Photo ajoutée" : "Ajouter une photo")
                    } icon: {
                        Image(systemName: photoAttached ? "checkmark.circle.fill" : "photo.badge.plus")
                            .foregroundStyle(photoAttached ? Color.green : Color.accentColor)
                    }
                }
                .accessibilityIdentifier("photo-picker")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Noter l’essai")
        .navigationSubtitle(recipeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                guard let note else { return }
                onSave(note, remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : remarks, realParams, photoBase64)
            } label: {
                Group {
                    if isSaving { ProgressView() } else { Text("Enregistrer l’essai") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(note == nil || isSaving)
            .accessibilityIdentifier("save-trial-button")
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task { await attachPhoto(newValue) }
        }
    }

    private var realParams: [Param] {
        targets.map { Param(key: $0.key, value: values[$0.key] ?? $0.value) }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }

    private func attachPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let jpeg = await Task.detached(priority: .userInitiated) {
            UIImage(data: data).flatMap { $0.resized(maxDimension: 1200).jpegData(compressionQuality: 0.7) }
        }.value
        if let jpeg {
            photoBase64 = jpeg.base64EncodedString()
            photoAttached = true
        }
    }
}
