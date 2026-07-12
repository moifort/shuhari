import SwiftUI

/// A single proposed parameter change: old value struck through, new value in the
/// accent colour — the highlighted diff on the proposal screen.
struct DiffRow: View {
    let key: String
    let from: String?
    let to: String

    var body: some View {
        HStack(spacing: 8) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if let from {
                Text(from)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(to)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        DiffRow(key: "Température", from: "93 °C", to: "92 °C")
        DiffRow(key: "Pré-infusion", from: nil, to: "5 s")
    }
    .padding()
}
