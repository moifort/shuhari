import SwiftUI

/// The fiche's header badges, in the iOS Photos "CINÉMATIQUE" style: a capsule
/// carrying the recipe type (icon + short uppercase label), then the displayed
/// version and the essai count. Primitive-first: no domain struct.
struct RecipeHeaderBadges: View {
    let type: RecipeType
    let versionNumber: Int?
    var essaiCount: Int = 0

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            capsule {
                type.iconImage(filled: false)
                Text(type.shortLabel.uppercased())
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

            if essaiCount > 0 {
                capsule {
                    Image(systemName: "flask")
                    Text("\(essaiCount)")
                        .monospacedDigit()
                }
                .accessibilityLabel("\(essaiCount) essais")
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
            RecipeHeaderBadges(type: type, versionNumber: 3, essaiCount: 2)
        }
        RecipeHeaderBadges(type: .plat, versionNumber: nil)
    }
    .padding()
}
