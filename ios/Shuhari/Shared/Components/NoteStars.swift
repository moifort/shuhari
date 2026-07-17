import SwiftUI

/// Read-only 5-star display of a note on the native 1–5 scale.
/// The mirror of the `StarRating` input, for showing a recipe's average note.
struct NoteStars: View {
    let note: Double

    private var filled: Int { Int(note.rounded()) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= filled ? "star.fill" : "star")
                    .foregroundStyle(star <= filled ? Color.yellow : Color(.tertiaryLabel))
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Note moyenne \(NoteFormat.average(note))")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        NoteStars(note: 5)
        NoteStars(note: 3.5)
        NoteStars(note: 2)
        NoteStars(note: 1)
    }
    .padding()
}
