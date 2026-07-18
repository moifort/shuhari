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
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, focusVersionNumber: 3)
        case "trial-pending":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, focusVersionNumber: 4)
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
                description: Text("Écrans : cuisine, recipe, recipe-tmx, recipe-fresh, next-trials, history, trial, trial-pending, execute, execute-tmx, capture, draft, import-preview, import-preview-tmx, ai-thinking, import-nothing-found")
            )
        }
    }
}

/// The full recipe fiche coordinator (`RecipeDetailView`) over a fixture, so the
/// gallery can exercise the floating action bar and its sheets offline. Owns the
/// navigation path the coordinator writes into.
private struct RecipeDetailGalleryScreen: View {
    let recipe: Recipe
    /// When set, focuses that version (the essai view: orange banner + change dots).
    var focusVersionNumber: Int? = nil
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RecipeDetailView(previewRecipe: recipe, path: $path, focusVersionNumber: focusVersionNumber)
        }
    }
}

/// The beaker CTA's sheet (`NextTrialsSheet`) presented over the fiche, so the
/// gallery can capture the versions awaiting a first run offline. Bœuf
/// bourguignon has several versions awaiting a first run (v1–v6).
private struct NextTrialsSheetGalleryScreen: View {
    var body: some View {
        Text("Fiche recette")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: .constant(true)) {
                NextTrialsSheet(
                    trials: [
                        .init(versionNumber: 6, change: "Sel 8 → 10 g", why: "Assaisonnement en retrait."),
                        .init(versionNumber: 5, change: "Cuisson 3 h → 3 h 30", why: "La viande était encore un peu ferme."),
                        .init(versionNumber: 4, change: "Température 93 → 92 °C", why: "Extraction trop amère."),
                        .init(versionNumber: 3, change: "Repos 10 → 20 min", why: nil),
                        .init(versionNumber: 2, change: "Oignons +50 g", why: "Manque de fond."),
                        .init(versionNumber: 1, change: nil, why: "Version d'origine importée."),
                    ],
                    onDelete: { _ in },
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

    private let library = [
        LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", type: .plat, category: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, updatedAt: Date()),
        LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .tmx, category: .plat, versionCount: 3, bestNote: 4, averageNote: 3.5, updatedAt: Date()),
        LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .tmx, category: .soupe, versionCount: 1, bestNote: nil, averageNote: nil, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
    ]

    var body: some View {
        NavigationStack {
            HomePage(
                library: library.filter { $0.type == selected },
                libraryGrouped: true,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: selected.label,
                typeFilter: .init(options: [.plat, .tmx], selection: $selected),
                sort: .constant(.lastModified),
                categoryFilter: .constant(nil),
                onSettings: {}
            )
        }
    }
}
#endif
