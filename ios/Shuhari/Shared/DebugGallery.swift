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
                HomePage(
                    data: Fixtures.homeData,
                    library: Fixtures.homeData.library,
                    libraryGrouped: true,
                    libraryLoading: false,
                    libraryHasMore: false,
                    libraryLoadMoreFailed: false,
                    title: "Carnet",
                    typeFilter: nil,
                    sort: .constant(.lastModified),
                    categoryFilter: .constant(nil),
                    onExecute: { _ in },
                    onSettings: {}
                )
            }
        case "cuisine":
            CuisineGalleryScreen()
        case "recipe":
            NavigationStack {
                RecipeDetailPage(recipe: Fixtures.bourguignon)
            }
        case "recipe-tmx":
            NavigationStack {
                RecipeDetailPage(recipe: Fixtures.risotto)
            }
        case "history":
            NavigationStack {
                HistoryPage(recipe: Fixtures.bourguignon)
            }
        case "trial":
            NavigationStack {
                TrialDetailPage(
                    recipeTitle: Fixtures.bourguignon.title,
                    trial: Fixtures.bourguignonTrials[1]
                )
            }
        case "execute":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.bourguignon.title,
                    version: Fixtures.bourguignonV4,
                    onDone: {}
                )
            }
        case "execute-tmx":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.risotto.title,
                    version: Fixtures.risottoV2,
                    onDone: {}
                )
            }
        case "capture":
            NavigationStack {
                CapturePage(
                    isSaving: false,
                    onSave: { _, _, _ in }
                )
            }
        case "proposal":
            NavigationStack {
                ProposalPage(
                    recipeTitle: Fixtures.bourguignon.title,
                    type: .plat,
                    proposal: Fixtures.proposal,
                    nextVersionNumber: 5,
                    variationTitle: Fixtures.proposal.variation?.title,
                    baseIngredients: Fixtures.bourguignonV4.ingredients,
                    baseSteps: Fixtures.bourguignonV4.steps,
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
            HomeTestItem(id: "boeuf", title: "Bœuf bourguignon", type: .plat, category: .plat, versionNumber: 5, change: "Cuisson 3 h → 3 h 30", why: "Viande encore ferme."),
        ],
        library: [
            LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", type: .plat, category: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, isDerived: false, updatedAt: Date()),
            LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .tmx, category: .plat, versionCount: 3, bestNote: 4, averageNote: 3.5, isDerived: false, updatedAt: Date()),
            LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .tmx, category: .soupe, versionCount: 1, bestNote: nil, averageNote: nil, isDerived: true, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
        ],
        recentTrials: []
    )

    var body: some View {
        NavigationStack {
            let filtered = data.filtered(to: [selected])
            HomePage(
                data: filtered,
                library: filtered.library,
                libraryGrouped: true,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: selected.label,
                typeFilter: .init(options: [.plat, .tmx], selection: $selected),
                sort: .constant(.lastModified),
                categoryFilter: .constant(nil),
                onExecute: { _ in },
                onSettings: {}
            )
        }
    }
}
#endif
