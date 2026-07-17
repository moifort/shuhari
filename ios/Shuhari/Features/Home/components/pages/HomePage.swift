import SwiftUI

/// The Carnet home screen: "À tester" banners, the library grouped by type, and
/// recent activity. Pure presentation — navigation and API calls are owned by
/// `HomeView`.
struct HomePage: View {
    /// The type filter offered on a multi-type tab (Cuisine), rendered as round
    /// glass toolbar buttons — one per type. `nil` on single-type tabs (Café,
    /// Cocktail), which need no selector.
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
        content
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("home-settings-button")
                    .accessibilityLabel("Réglages")
                }
                if let filter = typeFilter {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ForEach(filter.options) { type in
                            let isSelected = filter.selection.wrappedValue == type
                            Button {
                                filter.selection.wrappedValue = type
                            } label: {
                                type.iconImage(filled: false)
                            }
                            .tint(isSelected ? .accentColor : .primary)
                            .accessibilityLabel(type.label)
                            .accessibilityIdentifier("home-type-filter-\(type.rawValue)")
                        }
                    }
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
                        .init(id: "1", title: "Bœuf bourguignon", type: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, isDerived: false, updatedAt: Date()),
                        .init(id: "2", title: "Velouté de courge", type: .tmx, versionCount: 1, bestNote: 4, averageNote: 3.5, isDerived: false, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
                    ],
                    recentTrials: [
                        .init(id: "t1", recipeId: "1", versionNumber: 3, note: 4, remarks: "Équilibré, fondant.", realParams: [], photoUrl: nil, executedAt: Date()),
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
