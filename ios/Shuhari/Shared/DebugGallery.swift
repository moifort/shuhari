#if DEBUG
import SwiftUI

/// Debug-only screen gallery: renders any page with `Fixtures` data, without a
/// server or a signed-in user. Launch the app with `-gallery <screen>` (backed
/// by the `gallery` UserDefault) to jump straight to a screen — used to review
/// the design in the simulator and to capture screenshots.
struct DebugGallery: View {
    let screen: String

    var body: some View {
        switch screen {
        case "root":
            ContentView()
                .environment(HomeStore())
        case "home":
            NavigationStack {
                HomePage(data: Fixtures.homeData, title: "Café", typeFilter: nil, onExecute: { _ in }, onSettings: {})
            }
        case "cuisine":
            CuisineGalleryScreen()
        case "recipe":
            NavigationStack {
                RecipeDetailPage(recipe: Fixtures.espresso)
            }
        case "recipe-tmx":
            NavigationStack {
                RecipeDetailPage(recipe: Fixtures.risotto)
            }
        case "history":
            NavigationStack {
                HistoryPage(recipe: Fixtures.espresso)
            }
        case "trial":
            NavigationStack {
                TrialDetailPage(
                    recipeTitle: Fixtures.espresso.title,
                    trial: Fixtures.espressoTrials[1],
                    versionTargets: Fixtures.espressoV3.params,
                    onReplay: {}
                )
            }
        case "execute":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.espresso.title,
                    version: Fixtures.espressoV4,
                    replayParams: nil,
                    replayDate: nil,
                    onDone: {}
                )
            }
        case "execute-tmx":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.risotto.title,
                    version: Fixtures.risottoV2,
                    replayParams: nil,
                    replayDate: nil,
                    onDone: {}
                )
            }
        case "capture":
            NavigationStack {
                CapturePage(
                    targets: Fixtures.espressoV4.params,
                    isSaving: false,
                    onSave: { _, _, _, _ in }
                )
            }
        case "proposal":
            NavigationStack {
                ProposalPage(
                    recipeTitle: Fixtures.espresso.title,
                    type: .cafe,
                    proposal: Fixtures.proposal,
                    nextVersionNumber: 4,
                    variationTitle: Fixtures.proposal.variation?.title,
                    isWorking: false,
                    onRefuse: {},
                    onValidate: { _, _ in }
                )
            }
        case "import-preview":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysis, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "ai-thinking":
            AIThinkingCard(message: "Analyse IA…")
        default:
            ContentUnavailableView(
                "Écran inconnu : \(screen)",
                systemImage: "questionmark.square.dashed",
                description: Text("Écrans : home, cuisine, recipe, recipe-tmx, history, trial, execute, execute-tmx, capture, proposal, import-preview, ai-thinking")
            )
        }
    }
}

/// The multi-type Cuisine tab with its round type-filter CTAs and month-grouped
/// library — needs local state for the selected filter, so it lives in its own
/// view. Defaults to Thermomix to show the outlined custom symbol in the list.
private struct CuisineGalleryScreen: View {
    @State private var selected: RecipeType = .tmx

    private let data = HomeData(
        toTest: [
            HomeTestItem(id: "boeuf", title: "Bœuf bourguignon", type: .plat, versionNumber: 5, change: "Cuisson 3 h → 3 h 30", why: "Viande encore ferme."),
        ],
        library: [
            LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", type: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, isDerived: false, updatedAt: Date()),
            LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .tmx, versionCount: 3, bestNote: 4, averageNote: 3.5, isDerived: false, updatedAt: Date()),
            LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .tmx, versionCount: 1, bestNote: nil, averageNote: nil, isDerived: true, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
        ],
        recentTrials: []
    )

    var body: some View {
        NavigationStack {
            HomePage(
                data: data.filtered(to: [selected]),
                title: selected.label,
                typeFilter: .init(options: [.plat, .tmx], selection: $selected),
                onExecute: { _ in },
                onSettings: {}
            )
        }
    }
}
#endif
