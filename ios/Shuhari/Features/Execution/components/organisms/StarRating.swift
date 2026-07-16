import SwiftUI

/// A 5-star rating that maps to the app's 1–10 note: each star is worth 2 points,
/// so tapping star `i` sets the note to `i * 2` (2 / 4 / 6 / 8 / 10). The note stays
/// an `Int?` so the domain (promotion ≥ 8, colour thresholds, "/10") is unchanged.
struct StarRating: View {
    @Binding var selection: Int?

    /// Number of filled stars for the current note (0 until one is picked).
    private var filledStars: Int { (selection ?? 0) / 2 }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    selection = star * 2
                } label: {
                    Image(systemName: star <= filledStars ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(star <= filledStars ? Color.yellow : Color(.tertiaryLabel))
                        .frame(minWidth: 40, minHeight: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) étoile\(star > 1 ? "s" : "") sur 5")
                .accessibilityAddTraits(star == filledStars ? .isSelected : [])
                .accessibilityIdentifier("star-\(star)")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Note de l’essai")
    }
}

#Preview {
    struct Demo: View {
        @State private var note: Int? = 6
        var body: some View {
            Form {
                Section {
                    StarRating(selection: $note)
                        .listRowBackground(Color.clear)
                }
                Text(note.map { "Note : \($0)/10" } ?? "Pas de note")
            }
        }
    }
    return Demo()
}
