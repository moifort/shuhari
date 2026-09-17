import SwiftUI

/// The recipe sheet's header badges, in the iOS Photos "CINÉMATIQUE" style: a capsule
/// per tag the recipe is filed under (icon when it wears one + short uppercase label),
/// then the displayed version and how many versions wait to be cooked. They wrap
/// onto a second line rather than squeeze: a recipe can wear several tags.
/// Primitive-first: no domain struct.
struct RecipeHeaderBadges: View {
    /// What the recipe is filed under — the same tags the library row shows the
    /// icons of, with their words this time.
    var tags: [TagBadge] = []
    let versionNumber: Int?
    /// The versions waiting to be cooked. Zero hides the flask badge.
    var toTestCount: Int = 0
    /// On a coffee, a leading capsule says HOW it is brewed (ESPRESSO, V60): the
    /// method is what actually identifies the recipe. Nil on anything else.
    var methodLabel: String? = nil
    var methodIcon: Image? = nil

    var body: some View {
        FlowLayout(spacing: Theme.Spacing.s) {
            if let methodLabel {
                capsule {
                    methodIcon
                    Text(methodLabel.uppercased())
                }
                .accessibilityLabel("Méthode \(methodLabel)")
            }

            ForEach(tags) { tag in
                capsule {
                    tag.icon
                    Text(tag.label.uppercased())
                }
                .accessibilityLabel("Tag \(tag.label)")
            }

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
        RecipeHeaderBadges(
            tags: [Tag(label: "Thermomix", icon: .thermomix).badge],
            versionNumber: 3,
            toTestCount: 2
        )
        // Several tags wrap; one without an icon is its words alone.
        RecipeHeaderBadges(
            tags: [
                Tag(label: "Thermomix", icon: .thermomix).badge,
                Tag(label: "Invités", icon: .guests).badge,
                Tag(label: "Dimanche soir").badge,
            ],
            versionNumber: 3,
            toTestCount: 2
        )
        // Filed under nothing: the version leads.
        RecipeHeaderBadges(versionNumber: 1)
        // A coffee wears its brew method ahead of its tags.
        ForEach([BrewMethod.espresso, .v60, .frenchPress], id: \.self) { method in
            RecipeHeaderBadges(
                versionNumber: 2,
                methodLabel: method.label,
                methodIcon: method.iconImage
            )
        }
    }
    .padding()
}
