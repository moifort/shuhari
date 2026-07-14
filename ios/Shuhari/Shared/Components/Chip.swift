import SwiftUI

/// The shared neutral chip layout: optional icon + text in a systemFill capsule.
/// Backs `TypeChip` and any future informational chip so they all share one
/// geometry. For state-tinted tags use `StatusTag` instead.
struct Chip: View {
    var icon: String? = nil
    var image: Image? = nil
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let image {
                image
            } else if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemFill), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: 8) {
        Chip(icon: "mug.fill", text: "Café")
        Chip(icon: nil, text: "Sans icône")
    }
    .padding()
}
