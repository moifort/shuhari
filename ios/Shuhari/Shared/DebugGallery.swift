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
        case "recipe-thermomix":
            RecipeDetailGalleryScreen(recipe: Fixtures.risotto)
        case "recipe-fresh":
            RecipeDetailGalleryScreen(recipe: Fixtures.freshImport)
        case "history":
            NavigationStack {
                HistoryPage(recipe: Fixtures.bourguignon)
            }
        case "attempt":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, focusVersionNumber: 3)
        case "attempt-pending":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, focusVersionNumber: 4)
        case "execute":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.bourguignon.title,
                    version: Fixtures.bourguignonV4,
                    onDone: {}
                )
            }
        case "execute-thermomix":
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
                    type: .dish,
                    proposal: Fixtures.proposal,
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
        case "import-preview-thermomix":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysisThermomix, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "ai-thinking":
            AIThinkingCard(message: "Analyse IA…")
        case "import-nothing-found":
            ImportReviewSheet(galleryPhase: .nothingFound)
        default:
            ContentUnavailableView(
                "Écran inconnu : \(screen)",
                systemImage: "questionmark.square.dashed",
                description: Text("Écrans : cuisine, recipe, recipe-thermomix, recipe-fresh, history, attempt, attempt-pending, execute, execute-thermomix, capture, proposal, import-preview, import-preview-thermomix, ai-thinking, import-nothing-found")
            )
        }
    }
}

/// The full recipe sheet coordinator (`RecipeDetailView`) over a fixture, so the
/// gallery can exercise the floating action bar and its sheets offline. Owns the
/// navigation path the coordinator writes into.
private struct RecipeDetailGalleryScreen: View {
    let recipe: Recipe
    /// When set, focuses that version (the attempt view: orange banner + change dots).
    var focusVersionNumber: Int? = nil
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RecipeDetailView(previewRecipe: recipe, path: $path, focusVersionNumber: focusVersionNumber)
        }
    }
}

/// The multi-type cooking tab with its round type-filter CTAs and month-grouped
/// library — needs local state for the selected filter, so it lives in its own
/// view. Defaults to Thermomix to show the outlined custom symbol in the list.
private struct CuisineGalleryScreen: View {
    @State private var selected: RecipeType = .thermomix

    private let library = [
        LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", type: .dish, category: .main, versionCount: 4, bestRating: 5, updatedAt: Date()),
        LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .thermomix, category: .main, versionCount: 3, bestRating: 4, updatedAt: Date()),
        LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .thermomix, category: .soup, versionCount: 1, bestRating: nil, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
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
                typeFilter: .init(options: [.dish, .thermomix], selection: $selected),
                sort: .constant(.lastModified),
                categoryFilter: .constant(nil),
                onSettings: {}
            )
        }
    }
}
#endif
