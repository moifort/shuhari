import SwiftUI

/// The recipe sheet's header badges, in the iOS Photos "CINÉMATIQUE" style: a capsule
/// carrying the recipe type (icon + short uppercase label), then the displayed
/// version and how many versions wait to be cooked. Primitive-first: no domain struct.
struct RecipeHeaderBadges: View {
    let type: RecipeType
    let versionNumber: Int?
    /// The versions waiting to be cooked. Zero hides the flask badge.
    var toTestCount: Int = 0

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            capsule {
                type.iconImage(filled: false)
                Text(type.label.uppercased())
            }
            .accessibilityLabel("Type \(type.label)")

            if let versionNumber {
                capsule {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("v\(versionNumber)")
                        .monospacedDigit()
                }
                .accessibilityLabel("Version \(versionNumber)")
            }

            if toTestCount > 0 {
                capsule {
                    Image(systemName: "flask")
                    Text("\(toTestCount)")
                        .monospacedDigit()
                }
                .accessibilityLabel("\(toTestCount) versions à tester")
            }
        }
    }

    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 5) {
            content()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemFill), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(RecipeType.allCases) { type in
            RecipeHeaderBadges(type: type, versionNumber: 3, toTestCount: 2)
        }
        RecipeHeaderBadges(type: .dish, versionNumber: nil)
    }
    .padding()
}
