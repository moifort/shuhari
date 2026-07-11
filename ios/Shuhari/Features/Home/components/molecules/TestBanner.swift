import SwiftUI

/// The amber "À tester" banner: a pending version with its one-line change, the
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
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: "flask.fill")
            }
            .foregroundStyle(Color.orange)

            if let change, !change.isEmpty {
                Text(change)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
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
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .accessibilityIdentifier("execute-v\(versionNumber)-button")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    TestBanner(
        title: "Espresso — Brésil Santa Lúcia",
        versionNumber: 4,
        change: "Température 93 → 92 °C",
        why: "Le léger creux en milieu de bouche pointe vers une extraction trop chaude.",
        type: .cafe,
        onExecute: {}
    )
    .padding()
}
