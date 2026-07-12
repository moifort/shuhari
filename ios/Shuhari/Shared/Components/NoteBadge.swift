import SwiftUI

/// A trial note (1–10) shown as a coloured pill. Thresholds mirror the maquette:
/// ≥ 8 high (green), 6–7 medium (amber), < 6 low (red).
struct NoteBadge: View {
    let note: Int

    private var color: Color {
        if note >= 8 { .green }
        else if note >= 6 { .orange }
        else { .red }
    }

    var body: some View {
        Text("\(note)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .accessibilityLabel("Note \(note) sur 10")
    }
}

#Preview {
    HStack(spacing: 12) {
        NoteBadge(note: 9)
        NoteBadge(note: 6)
        NoteBadge(note: 3)
    }
    .padding()
}
