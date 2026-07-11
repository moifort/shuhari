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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Noter l’essai")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text("\(recipeTitle) — ce que tu as réellement fait et goûté.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                fieldLabel("Paramètres réels (pré-remplis avec les cibles)")
                VStack(spacing: 10) {
                    ForEach(targets) { target in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target.key)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(.tertiary)
                            TextField(target.value, text: binding(for: target.key))
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("real-param-\(target.key)")
                        }
                    }
                }

                fieldLabel("Note")
                NotePicker(selection: $note)

                fieldLabel("Remarques — qu’est-ce qui doit changer ?")
                TextField("Ex. : trop amer, coule trop vite, manque de liant…", text: $remarks, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("remarks-field")

                fieldLabel("Photo du résultat")
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(
                        photoAttached ? "Photo ajoutée" : "Ajouter une photo",
                        systemImage: photoAttached ? "checkmark.circle.fill" : "camera"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(photoAttached ? Color.green : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(13)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: photoAttached ? [] : [5]))
                            .foregroundStyle(photoAttached ? Color.green : Color(.separator))
                    )
                }
                .accessibilityIdentifier("photo-picker")

                Button {
                    guard let note else { return }
                    onSave(note, remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : remarks, realParams, photoBase64)
                } label: {
                    Group {
                        if isSaving { ProgressView() } else { Text("Enregistrer l’essai") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(note == nil || isSaving)
                .accessibilityIdentifier("save-trial-button")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Noter l’essai")
        .navigationBarTitleDisplayMode(.inline)
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

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
