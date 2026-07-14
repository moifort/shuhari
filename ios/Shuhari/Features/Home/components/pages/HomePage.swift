import SwiftUI

/// The Carnet home screen: "À tester" banners, the library grouped by type, and
/// recent activity. Pure presentation — navigation and API calls are owned by
/// `HomeView`.
struct HomePage: View {
    /// The segmented type filter shown atop a multi-type tab (Cuisine). `nil` on
    /// single-type tabs (Café, Cocktail), which need no selector.
    struct TypeFilter {
        let options: [RecipeType]
        let selection: Binding<RecipeType>
    }

    let data: HomeData
    let title: String
    let typeFilter: TypeFilter?
    let onExecute: (HomeTestItem) -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let filter = typeFilter {
                Picker("Type", selection: filter.selection) {
                    ForEach(filter.options) { type in
                        type.iconImage
                            .accessibilityLabel(type.label)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier("home-type-filter")
            }

            content
        }
        .navigationTitle(title)
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

    @ViewBuilder
    private var content: some View {
        if data.toTest.isEmpty && data.library.isEmpty {
            ContentUnavailableView {
                Label("Aucune recette", systemImage: "camera.viewfinder")
            } description: {
                // A filtered-but-empty segment isn't a first-run state: the tab may
                // hold recipes of the other type, so don't nudge to "import your first".
                Text(typeFilter == nil
                    ? "Importe ta première recette depuis l’onglet Importer — photo, texte ou lien."
                    : "Aucune recette de ce type pour l’instant.")
            }
        } else {
            List {
                ToTestSection(items: data.toTest, onExecute: onExecute)
                LibrarySection(data: data)
                RecentTrialsSection(trials: data.recentTrials, titleProvider: data.title(forRecipe:))
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

private struct HomePagePreview: View {
    @State private var selectedType: RecipeType = .plat

    var body: some View {
        NavigationStack {
            HomePage(
                data: HomeData(
                    toTest: [
                        .init(id: "1", title: "Bœuf bourguignon", type: .plat, versionNumber: 4, change: "Cuisson 3 h → 3 h 30", why: "Viande trop ferme."),
                    ],
                    library: [
                        .init(id: "1", title: "Bœuf bourguignon", type: .plat, currentVersionNumber: 3, averageNote: 7.5, toTestNumber: 4, isDerived: false),
                        .init(id: "2", title: "Velouté de courge", type: .tmx, currentVersionNumber: 1, averageNote: 7.0, toTestNumber: nil, isDerived: false),
                    ],
                    recentTrials: [
                        .init(id: "t1", recipeId: "1", versionNumber: 3, note: 8, remarks: "Équilibré, fondant.", realParams: [], photoUrl: nil, executedAt: Date()),
                    ]
                ).filtered(to: [selectedType]),
                title: "Cuisine",
                typeFilter: .init(options: [.plat, .tmx], selection: $selectedType),
                onExecute: { _ in },
                onSettings: {}
            )
        }
    }
}

#Preview {
    HomePagePreview()
}
