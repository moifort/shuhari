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
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon)
        case "recipe-tmx":
            RecipeDetailGalleryScreen(recipe: Fixtures.risotto)
        case "recipe-fresh":
            RecipeDetailGalleryScreen(recipe: Fixtures.freshImport)
        case "next-trials":
            NextTrialsSheetGalleryScreen()
        case "history":
            NavigationStack {
                HistoryPage(recipe: Fixtures.bourguignon)
            }
        case "trial":
            NavigationStack {
                EssaiDetailPage(
                    recipeTitle: Fixtures.bourguignon.title,
                    version: Fixtures.bourguignonV3
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
        case "draft":
            NavigationStack {
                DraftPage(
                    type: .plat,
                    draft: Fixtures.draft,
                    nextVersionNumber: 5,
                    baseIngredients: Fixtures.bourguignonV4.ingredients,
                    baseSteps: Fixtures.bourguignonV4.steps,
                    isWorking: false,
                    onClose: {},
                    onValidate: { _ in }
                )
            }
        case "import-preview":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysis, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "import-preview-tmx":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysisTmx, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "ai-thinking":
            AIThinkingCard(message: "Analyse IA…")
        case "import-nothing-found":
            ImportReviewSheet(galleryPhase: .nothingFound)
        default:
            ContentUnavailableView(
                "Écran inconnu : \(screen)",
                systemImage: "questionmark.square.dashed",
                description: Text("Écrans : home, cuisine, recipe, recipe-tmx, recipe-fresh, next-trials, history, trial, execute, execute-tmx, capture, draft, import-preview, import-preview-tmx, ai-thinking, import-nothing-found")
            )
        }
    }
}

/// The full recipe fiche coordinator (`RecipeDetailView`) over a fixture, so the
/// gallery can exercise the floating action bar and its sheets offline. Owns the
/// navigation path the coordinator writes into.
private struct RecipeDetailGalleryScreen: View {
    let recipe: Recipe
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RecipeDetailView(previewRecipe: recipe, path: $path)
        }
    }
}

/// The beaker CTA's sheet (`NextTrialsSheet`) presented over the fiche, so the
/// gallery can capture the versions awaiting a first run offline. Bœuf
/// bourguignon has one version awaiting a first run (v4).
private struct NextTrialsSheetGalleryScreen: View {
    var body: some View {
        Text("Fiche recette")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: .constant(true)) {
                NextTrialsSheet(
                    trials: [
                        .init(versionNumber: 4, change: "Cuisson 3 h → 3 h 30", why: "La viande était encore un peu ferme."),
                    ],
                    onSelect: { _ in }
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
            LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", type: .plat, category: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, updatedAt: Date()),
            LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .tmx, category: .plat, versionCount: 3, bestNote: 4, averageNote: 3.5, updatedAt: Date()),
            LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .tmx, category: .soupe, versionCount: 1, bestNote: nil, averageNote: nil, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
        ],
        recentEssais: []
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
