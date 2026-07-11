import SwiftUI

/// The Carnet home screen: header, "À tester" banners, the library grouped by
/// type, and recent activity. Pure presentation — navigation and API calls are
/// owned by `HomeView`.
struct HomePage: View {
    let data: HomeData
    let onExecute: (HomeTestItem) -> Void
    let onSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ToTestSection(items: data.toTest, onExecute: onExecute)
                LibrarySection(data: data)
                RecentTrialsSection(trials: data.recentTrials, titleProvider: data.title(forRecipe:))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Carnet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityIdentifier("home-settings-button")
                .accessibilityLabel("Réglages")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(.tertiary)
            Text("Carnet")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("Ton labo culinaire — \(data.library.count) recette\(data.library.count > 1 ? "s" : "") en cours d’amélioration.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        HomePage(
            data: HomeData(
                toTest: [
                    .init(id: "1", title: "Espresso — Brésil", type: .cafe, versionNumber: 4, change: "Température 93 → 92 °C", why: "Extraction trop chaude."),
                ],
                library: [
                    .init(id: "1", title: "Espresso — Brésil", type: .cafe, currentVersionNumber: 3, averageNote: 7.5, toTestNumber: 4, isDerived: false),
                    .init(id: "2", title: "Negroni", type: .cocktail, currentVersionNumber: 1, averageNote: 7.0, toTestNumber: nil, isDerived: false),
                ],
                recentTrials: [
                    .init(id: "t1", recipeId: "1", versionNumber: 3, note: 8, remarks: "Équilibré, chocolat noir.", realParams: [], photoUrl: nil, executedAt: Date()),
                ]
            ),
            onExecute: { _ in },
            onSettings: {}
        )
    }
}
