import PhotosUI
import SwiftUI

/// Capture the attempt's feedback: a 5-star rating, then remarks and photos of the
/// result. Validation lives in the top-right toolbar; the flow provides the close
/// button.
struct CapturePage: View {
    let isSaving: Bool
    let onSave: (_ rating: Int, _ remarks: String, _ photoBase64: String?) -> Void

    /// A picked photo kept both decoded (for the thumbnail) and encoded (payload).
    private struct LoadedPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
        let base64: String
    }

    @State private var rating: Int?
    @State private var remarks: String = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [LoadedPhoto] = []

    var body: some View {
        Form {
            Section {
                StarRating(selection: $rating)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            .listRowBackground(Color.clear)

            // Remarks and photos share one block.
            Section {
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
                    guard let rating else { return }
                    onSave(rating, remarks.trimmingCharacters(in: .whitespacesAndNewlines), photos.first?.base64)
                } label: {
                    if isSaving { ProgressView() } else { Image(systemName: "checkmark") }
                }
                .disabled(rating == nil || isSaving)
                .accessibilityIdentifier("save-attempt-button")
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
}

#Preview {
    NavigationStack {
        CapturePage(
            isSaving: false,
            onSave: { _, _, _ in }
        )
    }
}
