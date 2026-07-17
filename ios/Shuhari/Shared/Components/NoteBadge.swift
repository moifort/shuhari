import SwiftUI

/// A trial note (1–5) shown as a coloured pill. Thresholds mirror the maquette:
/// ≥ 4 high (green), 3 medium (amber), ≤ 2 low (red).
struct NoteBadge: View {
    let note: Int

    var body: some View {
        Text("\(note)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Theme.Status.note(note), in: Circle())
            .accessibilityLabel("Note \(note) sur 5")
    }
}

#Preview {
    HStack(spacing: 12) {
        NoteBadge(note: 5)
        NoteBadge(note: 3)
        NoteBadge(note: 1)
    }
    .padding()
}
