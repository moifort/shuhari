import SwiftUI

/// A small status capsule: icon + label tinted by the business state. The one
/// primitive behind "courante" / "à tester" / version tags, so a status always
/// looks — and reads to VoiceOver — the same everywhere.
struct StatusTag: View {
    enum Kind {
        case current
        case toTest
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
        case .current: "courante"
        case .toTest: "à tester"
        case .version(let number): "v\(number)"
        }
    }

    private var icon: String? {
        switch kind {
        case .current: "checkmark.seal.fill"
        case .toTest: "flask.fill"
        case .version: nil
        }
    }

    private var color: Color {
        switch kind {
        case .current: Theme.Status.current
        case .toTest: Theme.Status.toTest
        case .version: Color.secondary
        }
    }

    private var background: Color {
        switch kind {
        case .current: Theme.Status.current.opacity(0.14)
        case .toTest: Theme.Status.toTest.opacity(0.14)
        case .version: Color(.systemFill)
        }
    }

    private var accessibilityText: String {
        switch kind {
        case .current: "Version courante"
        case .toTest: "À tester"
        case .version(let number): "Version \(number)"
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        StatusTag(kind: .current)
        StatusTag(kind: .toTest)
        StatusTag(kind: .version(4))
    }
    .padding()
}
