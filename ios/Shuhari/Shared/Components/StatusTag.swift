import SwiftUI

/// A small status capsule: icon + label tinted by the business state. The one
/// primitive behind the "en cours" highlight and version tags, so a status always
/// looks — and reads to VoiceOver — the same everywhere.
struct StatusTag: View {
    enum Kind {
        /// The version you are currently iterating on (the recipe's `versionToOpen`).
        case working
        case version(Int)
    }

    let kind: Kind

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 3)
        .background(background, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var text: String {
        switch kind {
        case .working: "en cours"
        case .version(let number): "v\(number)"
        }
    }

    private var icon: String? {
        switch kind {
        case .working: "wrench.and.screwdriver.fill"
        case .version: nil
        }
    }

    private var color: Color {
        switch kind {
        case .working: Theme.Status.essai
        case .version: Color.secondary
        }
    }

    private var background: Color {
        switch kind {
        case .working: Theme.Status.essai.opacity(0.14)
        case .version: Color(.systemFill)
        }
    }

    private var accessibilityText: String {
        switch kind {
        case .working: "Celle sur laquelle je travaille"
        case .version(let number): "Version \(number)"
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        StatusTag(kind: .working)
        StatusTag(kind: .version(4))
    }
    .padding()
}
