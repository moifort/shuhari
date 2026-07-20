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
        case "cuisine-course":
            CuisineGalleryScreen(sort: .dishCategory)
        case "cuisine-favorites":
            CuisineGalleryScreen(lens: .favorites)
        case "cuisine-thermomix":
            CuisineGalleryScreen(lens: .type(.thermomix))
        case "cuisine-loading":
            NavigationStack {
                HomePage(
                    library: [],
                    libraryGrouping: .month,
                    libraryLoading: true,
                    libraryHasMore: false,
                    libraryLoadMoreFailed: false,
                    title: "Cuisine",
                    lensPicker: nil,
                    sort: .constant(.lastModified),
                    categoryFilter: .constant(nil),
                    onSettings: {}
                )
            }
        case "recipe":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon)
        case "recipe-thermomix":
            RecipeDetailGalleryScreen(recipe: Fixtures.risotto)
        case "recipe-fresh":
            RecipeDetailGalleryScreen(recipe: Fixtures.freshImport)
        case "recipe-delete":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, startOnDeleteConfirm: true)
        case "history":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    HistorySheet(previewRecipe: Fixtures.bourguignon)
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
                    proposal: Fixtures.proposal,
                    nextVersionNumber: 5,
                    baseIngredients: Fixtures.bourguignonV4.ingredients,
                    baseSteps: Fixtures.bourguignonV4.content.stepsWithSettings,
                    baseTips: Fixtures.bourguignonV4.tips,
                    isWorking: false,
                    suggestedRecipeTitle: Fixtures.bourguignon.title,
                    onClose: {},
                    onValidate: { _ in },
                    onCreateRecipe: { _, _ in }
                )
            }
        case "proposal-thermomix":
            NavigationStack {
                ProposalPage(
                    proposal: Fixtures.proposalThermomix,
                    nextVersionNumber: 3,
                    baseIngredients: Fixtures.risottoV2.ingredients,
                    baseSteps: Fixtures.risottoV2.content.stepsWithSettings,
                    baseTips: Fixtures.risottoV2.tips,
                    isWorking: false,
                    suggestedRecipeTitle: Fixtures.risotto.title,
                    onClose: {},
                    onValidate: { _ in },
                    onCreateRecipe: { _, _ in }
                )
            }
        case "tips-section":
            // The recipe sheet's closing section on its own — it sits below the steps,
            // too far down the sheet to be seen without scrolling.
            List {
                TipsSection(tips: Fixtures.bourguignonV3.tips)
            }
        case "tips-proposal":
            NavigationStack {
                TipsProposalPage(
                    proposedTips: Fixtures.proposal.tips,
                    baseTips: Fixtures.bourguignonV3.tips,
                    isWorking: false,
                    onClose: {},
                    onValidate: { _ in }
                )
            }
        case "to-test":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    ToTestSheet(versions: Fixtures.bourguignon.versionsToTest, onSelect: { _ in })
                }
        case "to-test-empty":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    ToTestSheet(versions: [], onSelect: { _ in })
                }
        case "recipe-edit":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    RecipeEditSheet(
                        initialTitle: Fixtures.bourguignon.title,
                        initialCategory: Fixtures.bourguignon.category
                    ) { _, _ in }
                }
        case "improve":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    ImproveFlowView(
                        recipeId: Fixtures.bourguignon.id,
                        version: Fixtures.bourguignonV4,
                        nextVersionNumber: 5,
                        recipeTitle: Fixtures.bourguignon.title,
                        recipeType: Fixtures.bourguignon.type,
                        category: Fixtures.bourguignon.category,
                        onFinished: {}
                    )
                }
        case "viewfinder":
            ZStack {
                Color(white: 0.35).ignoresSafeArea()
                ViewfinderOverlay()
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
        case "login":
            LoginView()
        case "settings-data":
            NavigationStack {
                ImportExportSettingsView()
            }
        case "quota":
            QuotaGalleryScreen()
        case "quota-premium":
            QuotaGalleryScreen(isPremium: true)
        case "premium":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    PremiumSheet()
                }
        case "import-quota-exhausted":
            ImportReviewSheet(galleryPhase: .quotaExhausted)
        case "import-premium-required":
            ImportReviewSheet(galleryPhase: .premiumRequired)
        default:
            ContentUnavailableView(
                "Écran inconnu : \(screen)",
                systemImage: "questionmark.square.dashed",
                description: Text("Écrans : cuisine, cuisine-course, cuisine-favorites, cuisine-thermomix, cuisine-loading, recipe, recipe-thermomix, recipe-fresh, history, attempt, attempt-pending, execute, execute-thermomix, capture, proposal, proposal-thermomix, to-test, to-test-empty, recipe-edit, improve, viewfinder, import-preview, import-preview-thermomix, ai-thinking, import-nothing-found, login, settings-data, quota, quota-premium, premium, import-quota-exhausted, import-premium-required")
            )
        }
    }
}

/// The settings' subscription section, offline: the free plan with one import
/// left and the iteration meter spent, or the unlimited Premium plan.
private struct QuotaGalleryScreen: View {
    var isPremium = false

    var body: some View {
        NavigationStack {
            List {
                QuotaSection(
                    isPremium: isPremium,
                    meters: [
                        .init(
                            title: "Imports IA",
                            icon: "square.and.arrow.down",
                            used: isPremium ? 12 : 2,
                            limit: isPremium ? nil : 3
                        ),
                        .init(
                            title: "Itérations IA",
                            icon: "sparkles",
                            used: isPremium ? 47 : 5,
                            limit: isPremium ? nil : 5
                        ),
                    ],
                    renewsOn: Date(timeIntervalSince1970: 1_785_542_400)
                )
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
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
    /// Opens straight on the delete dialog (version vs whole recipe).
    var startOnDeleteConfirm = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RecipeDetailView(
                previewRecipe: recipe,
                path: $path,
                focusVersionNumber: focusVersionNumber,
                startOnDeleteConfirm: startOnDeleteConfirm
            )
        }
    }
}

/// The multi-type cooking tab with its round lens CTAs and sectioned library — needs
/// local state for the selected lens and sort, so it lives in its own view. Defaults
/// to the whole library, as the app does; the sort picker is live, so both section
/// axes (month, course) are reachable.
private struct CuisineGalleryScreen: View {
    @State private var lens: LibraryLens
    @State private var sort: RecipeSortOption

    init(lens: LibraryLens = .all, sort: RecipeSortOption? = nil) {
        self._lens = State(initialValue: lens)
        self._sort = State(initialValue: sort ?? lens.defaultSort)
    }

    private let library = [
        LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", type: .dish, category: .main, favorite: true, versionCount: 4, toTestCount: 1, bestRating: 5, updatedAt: Date()),
        LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .thermomix, category: .main, favorite: false, versionCount: 3, toTestCount: 1, bestRating: 4, updatedAt: Date()),
        LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .thermomix, category: .soup, favorite: true, versionCount: 1, toTestCount: 0, bestRating: nil, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
    ]

    var body: some View {
        NavigationStack {
            HomePage(
                library: library.filter { recipe in
                    switch lens {
                    case .all: true
                    case .favorites: recipe.favorite
                    case .type(let type): recipe.type == type
                    }
                },
                libraryGrouping: sort == .lastModified ? .month : .course,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: lens.label,
                lensPicker: .init(
                    options: [.all, .type(.dish), .type(.thermomix), .favorites],
                    selection: $lens
                ),
                sort: $sort,
                categoryFilter: .constant(nil),
                onSettings: {}
            )
        }
    }
}
#endif
