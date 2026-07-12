import SwiftUI

/// The one way a changed value is displayed: old value struck through, arrow,
/// new value emphasised in the "changed" colour. Inherits the font from its
/// context and reads as a single VoiceOver element ("de X à Y").
struct DiffValue: View {
    let from: String?
    let to: String

    var body: some View {
        HStack(spacing: 6) {
            if let from {
                Text(from)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(to)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Theme.Status.changed)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(from.map { "de \($0) à \(to)" } ?? to)
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 12) {
        DiffValue(from: "93 °C", to: "92 °C")
        DiffValue(from: nil, to: "5 s")
    }
    .padding()
}
