import SwiftUI

/// The "À tester" list row: a pending version with its one-line change, the
/// rationale, and a prominent execute button. Reused on Home and the recipe fiche.
struct TestBanner: View {
    let title: String?
    let versionNumber: Int
    let change: String?
    let why: String?
    let type: RecipeType
    var executeLabel: String? = nil
    let onExecute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title.map { "\($0) — v\(versionNumber)" } ?? "v\(versionNumber) à tester")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "flask.fill")
            }
            .foregroundStyle(Theme.Status.toTest)

            if let change, !change.isEmpty {
                Text(change)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            if let why, !why.isEmpty {
                Text(why)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: onExecute) {
                Text(executeLabel ?? "Exécuter la v\(versionNumber)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.Status.toTest)
            .accessibilityIdentifier("execute-v\(versionNumber)-button")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        TestBanner(
            title: "Espresso — Brésil Santa Lúcia",
            versionNumber: 4,
            change: "Température 93 → 92 °C",
            why: "Le léger creux en milieu de bouche pointe vers une extraction trop chaude.",
            type: .cafe,
            onExecute: {}
        )
    }
}
