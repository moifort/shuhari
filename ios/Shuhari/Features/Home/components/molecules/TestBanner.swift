import SwiftUI

/// The "à tester" hero card: the pending version, its one-line change, the
/// rationale and the execute CTA — the screen's #1 action. A tinted card on
/// the content layer (no glass), reused on Home and the recipe fiche. Callers
/// clear the list-row chrome (`listRowInsets`/`listRowBackground`).
struct TestBanner: View {
    let title: String?
    let versionNumber: Int
    let change: String?
    let why: String?
    let type: RecipeType
    var executeLabel: String? = nil
    let onExecute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                StatusTag(kind: .toTest)
                Spacer()
                Text("v\(versionNumber)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let title {
                    Text(title)
                        .font(.headline)
                }
                if let change, !change.isEmpty {
                    Text(change)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                if let why, !why.isEmpty {
                    Text(why)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onExecute) {
                Text(executeLabel ?? "Exécuter la v\(versionNumber)")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Theme.Status.toTest)
            .accessibilityIdentifier("execute-v\(versionNumber)-button")
        }
        .padding(Theme.Spacing.xl)
        .background(
            LinearGradient(
                colors: [Theme.Status.toTest.opacity(0.16), Theme.Status.toTest.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: Theme.Radius.card)
        )
        .containerShape(.rect(cornerRadius: Theme.Radius.card))
    }
}

#Preview {
    List {
        Section {
            TestBanner(
                title: "Espresso — Brésil Santa Lúcia",
                versionNumber: 4,
                change: "Température 93 → 92 °C",
                why: "Le léger creux en milieu de bouche pointe vers une extraction trop chaude.",
                type: .cafe,
                onExecute: {}
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}
