import PhotosUI
import SwiftUI

/// Capture the trial's feedback: a 5-star note, then (when the recipe has any)
/// editable real parameters, remarks and photos of the result. Validation lives
/// in the top-right toolbar; the flow provides the close button.
struct CapturePage: View {
    let targets: [Param]
    let isSaving: Bool
    let onSave: (_ note: Int, _ remarks: String, _ realParams: [Param], _ photoBase64: String?) -> Void

    /// A picked photo kept both decoded (for the thumbnail) and encoded (payload).
    private struct LoadedPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
        let base64: String
    }

    @State private var values: [String: String]
    @State private var note: Int?
    @State private var remarks: String = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [LoadedPhoto] = []
    @FocusState private var focusedParam: String?

    init(
        targets: [Param],
        isSaving: Bool,
        onSave: @escaping (_ note: Int, _ remarks: String, _ realParams: [Param], _ photoBase64: String?) -> Void
    ) {
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self._values = State(initialValue: Dictionary(uniqueKeysWithValues: targets.map { ($0.key, $0.value) }))
    }

    var body: some View {
        Form {
            Section {
                StarRating(selection: $note)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            .listRowBackground(Color.clear)

            // Real parameters, remarks and photos share one block.
            Section {
                if !targets.isEmpty {
                    ForEach(targets) { target in
                        LabeledContent(target.key) {
                            TextField(target.value, text: binding(for: target.key))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                                .submitLabel(target.key == targets.last?.key ? .done : .next)
                                .focused($focusedParam, equals: target.key)
                                .onSubmit { focusNextParam(after: target.key) }
                                .accessibilityIdentifier("real-param-\(target.key)")
                        }
                    }
                }

                TextField("Ex. : trop amer, coule trop vite, manque de liant…", text: $remarks, axis: .vertical)
                    .lineLimit(8...20)
                    .frame(minHeight: 140, alignment: .top)
                    .accessibilityIdentifier("remarks-field")

                photoRow
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, Theme.Spacing.s, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Remarque")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    guard let note else { return }
                    onSave(note, remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : remarks, realParams, photos.first?.base64)
                } label: {
                    if isSaving { ProgressView() } else { Image(systemName: "checkmark") }
                }
                .disabled(note == nil || isSaving)
                .accessibilityIdentifier("save-trial-button")
                .accessibilityLabel("Enregistrer l’essai")
            }
        }
        .onChange(of: photoItems) { _, newValue in
            Task { await loadPhotos(newValue) }
        }
    }

    // MARK: - Photos

    private var photoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(photos) { photo in
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: Theme.Radius.control))
                }

                PhotosPicker(selection: $photoItems, maxSelectionCount: 5, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 72, height: 72)
                        .background(Color(.systemFill), in: .rect(cornerRadius: Theme.Radius.control))
                }
                .accessibilityIdentifier("photo-picker")
                .accessibilityLabel("Ajouter des photos")
            }
            .padding(.vertical, 2)
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [LoadedPhoto] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let jpeg = await Task.detached(priority: .userInitiated) {
                UIImage(data: data).flatMap { $0.resized(maxDimension: 1200).jpegData(compressionQuality: 0.7) }
            }.value
            if let jpeg, let image = UIImage(data: jpeg) {
                loaded.append(LoadedPhoto(image: image, base64: jpeg.base64EncodedString()))
            }
        }
        photos = loaded
    }

    // MARK: - Real params

    private var realParams: [Param] {
        targets.map { Param(key: $0.key, value: values[$0.key] ?? $0.value) }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }

    private func focusNextParam(after key: String) {
        guard let index = targets.firstIndex(where: { $0.key == key }), targets.index(after: index) < targets.endIndex else {
            focusedParam = nil
            return
        }
        focusedParam = targets[targets.index(after: index)].key
    }
}

#Preview {
    NavigationStack {
        CapturePage(
            targets: Fixtures.espressoV4.params,
            isSaving: false,
            onSave: { _, _, _, _ in }
        )
    }
}
