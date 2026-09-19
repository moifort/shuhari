#if DEBUG
import SwiftUI

/// Debug-only screen gallery: renders any page with `Fixtures` data, without a
/// server or a signed-in user. Launch the app with `-gallery <screen>` (backed
/// by the `gallery` UserDefault) to jump straight to a screen — used to review
/// the design in the simulator and to capture screenshots.
struct DebugGallery: View {
    let screen: String
    /// Every gallery screen gets a store: the ones that present the Premium sheet
    /// read it from the environment, and an unconfigured one simply sells nothing.
    @State private var subscription = SubscriptionStore()
    /// Likewise for the session: screens that show the account read it from the
    /// environment, and with nobody signed in they simply show no address.
    @State private var authSession = AuthSession()

    var body: some View {
        gallery
            .environment(subscription)
            .environment(authSession)
    }

    @ViewBuilder
    private var gallery: some View {
        switch screen {
        case "root":
            ContentView()
        case "cuisine":
            CuisineGalleryScreen()
        case "cuisine-recent":
            CuisineGalleryScreen(sort: .lastModified)
        case "cuisine-search":
            CuisineGalleryScreen(searchText: "ri")
        case "cuisine-refreshing":
            CuisineGalleryScreen(refreshing: true)
        case "cuisine-refresh-failed":
            CuisineGalleryScreen(refreshFailed: true)
        case "coffee":
            CoffeeGalleryScreen()
        case "coffee-recent":
            CoffeeGalleryScreen(sort: .lastModified)
        case "cuisine-loading":
            NavigationStack {
                HomePage(
                    library: [],
                    libraryGrouping: .month,
                    libraryLoading: true,
                    libraryHasMore: false,
                    libraryLoadMoreFailed: false,
                    title: "Cuisine",
                    sort: .constant(.lastModified),
                    facet: .course(selection: .constant(nil)),
                    search: .idle,
                    onSettings: {}
                )
            }
        case "recipe":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon)
        case "recipe-component":
            RecipeDetailGalleryScreen(recipe: Fixtures.ravioli)
        case "link-recipe":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    LinkRecipeSheet(excludedId: Fixtures.ravioli.id) { _, _ in }
                }
        case "link-weight":
            NavigationStack {
                LinkWeightForm(
                    title: Fixtures.doughComponent.title,
                    ingredients: Fixtures.doughComponent.ingredients.map { ($0.name, $0.quantity) },
                    initialScale: Fixtures.doughComponent.scale,
                    onConfirm: { _ in }
                )
            }
        case "recipe-oven":
            RecipeDetailGalleryScreen(recipe: Fixtures.quiche)
        case "recipe-oven-probe":
            RecipeDetailGalleryScreen(recipe: Fixtures.gigot)
        case "oven-start":
            OvenSectionGalleryScreen(running: nil)
        case "oven-assisted":
            OvenSectionGalleryScreen(running: nil, assisted: true)
        case "oven-running":
            OvenSectionGalleryScreen(running: "Cuisson en cours · 12 min")
        case "oven-starting":
            OvenSectionGalleryScreen(running: nil, isStarting: true)
        case "recipe-thermomix":
            RecipeDetailGalleryScreen(recipe: Fixtures.risotto)
        case "recipe-coffee":
            RecipeDetailGalleryScreen(recipe: Fixtures.espresso)
        case "recipe-coffee-v60":
            RecipeDetailGalleryScreen(recipe: Fixtures.v60)
        case "recipe-fresh":
            RecipeDetailGalleryScreen(recipe: Fixtures.freshImport)
        case "recipe-delete":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, startOnDeleteConfirm: true)
        case "recipe-copy":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, startOnCopyPrompt: true)
        case "history":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    HistorySheet(recipe: Fixtures.bourguignon, onSelect: { _ in })
                }
        case "attempt":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, focusVersionNumber: 3)
        case "attempt-pending":
            RecipeDetailGalleryScreen(recipe: Fixtures.bourguignon, focusVersionNumber: 4)
        // In its sheet, at the height the flow opens it — the form is only ever
        // read through that window, so reviewing it outside of one proves nothing.
        case "capture":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    NavigationStack {
                        CapturePage(isSaving: false, onSave: { _ in })
                    }
                    .presentationDetents([.fraction(0.7), .large])
                    .presentationDragIndicator(.visible)
                }
        case "proposal":
            NavigationStack {
                ProposalPage(
                    proposal: Fixtures.proposal,
                    nextVersionNumber: 5,
                    baseIngredients: Fixtures.bourguignonV4.ingredients,
                    baseMiseEnPlace: Fixtures.bourguignonV4.miseEnPlace,
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
        case "proposal-coffee":
            NavigationStack {
                CoffeeProposalPage(
                    proposal: Fixtures.proposalCoffee,
                    nextVersionNumber: 3,
                    baseParameters: Fixtures.v60V2.content.coffeeParameters ?? .empty,
                    baseTips: Fixtures.v60V2.tips,
                    vocabulary: Fixtures.coffeeVocabulary,
                    isWorking: false,
                    suggestedRecipeTitle: Fixtures.v60.title,
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
                // A version with no tips renders no section at all.
                TipsSection(tips: [])
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
        // The one edit surface, in the states worth looking at: a dish, a Thermomix
        // recipe and its machine settings, a bake, a coffee, and a version fresh out
        // of an import with nothing filled in yet.
        case "recipe-edit":
            RecipeEditGalleryScreen(recipe: Fixtures.bourguignon, version: Fixtures.bourguignonV3)
        case "recipe-edit-thermomix":
            RecipeEditGalleryScreen(recipe: Fixtures.risotto, version: Fixtures.risottoV2)
        case "recipe-edit-oven":
            RecipeEditGalleryScreen(recipe: Fixtures.quiche, version: Fixtures.quicheV1)
        // The connected oven is set right now: the section offers to copy its dials.
        case "recipe-edit-oven-copy":
            RecipeEditGalleryScreen(
                recipe: Fixtures.bourguignon,
                version: Fixtures.bourguignonV3,
                applianceSettings: OvenSettings(
                    program: .steamCombi,
                    temperature: 180,
                    duration: 25,
                    core: nil
                )
            )
        case "recipe-edit-coffee":
            RecipeEditGalleryScreen(recipe: Fixtures.v60, version: Fixtures.v60V2)
        case "recipe-edit-fresh":
            RecipeEditGalleryScreen(recipe: Fixtures.freshImport, version: Fixtures.freshImportV1)
        // Every section empty at once: the import recognised nothing, and this sheet
        // is the only place any of it can be written.
        case "recipe-edit-blank":
            RecipeEditGalleryScreen(recipe: Fixtures.blankImport, version: Fixtures.blankImportV1)
        case "viewfinder":
            ZStack {
                Color(white: 0.35).ignoresSafeArea()
                ViewfinderOverlay()
            }
        case "composer":
            ComposerGalleryScreen()
        case "composer-empty":
            ComposerGalleryScreen(photoCount: 0, text: "")
        case "composer-coffee":
            ComposerGalleryScreen(photoCount: 0, text: "", flow: .coffee)
        case "import-preview":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysis, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "import-preview-thermomix":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysisThermomix, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "import-preview-coffee":
            NavigationStack {
                CoffeeImportPreviewPage(
                    analysis: Fixtures.importAnalysisCoffee,
                    vocabulary: Fixtures.coffeeVocabulary,
                    isSaving: false,
                    onCancel: {},
                    onSave: { _ in }
                )
            }
        case "import-preview-coffee-empty":
            NavigationStack {
                CoffeeImportPreviewPage(
                    analysis: Fixtures.importAnalysisCoffeeSparse,
                    vocabulary: Fixtures.coffeeVocabulary,
                    isSaving: false,
                    onCancel: {},
                    onSave: { _ in }
                )
            }
        case "import-preview-coffee-milk":
            NavigationStack {
                CoffeeImportPreviewPage(
                    analysis: Fixtures.importAnalysisCoffeeMilk,
                    vocabulary: Fixtures.coffeeVocabulary,
                    isSaving: false,
                    onCancel: {},
                    onSave: { _ in }
                )
            }
        case "ai-thinking":
            AIThinkingCard(message: "Analyse IA…")
        case "import-nothing-found":
            ImportReviewSheet(galleryPhase: .nothingFound)
        case "login":
            LoginView()
        case "settings":
            SettingsHomeView()
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
                    PremiumSheet(galleryOffers: Fixtures.premiumOffers)
                }
        case "premium-live":
            Color.clear
                .sheet(isPresented: .constant(true)) {
                    PremiumSheet(store: subscription)
                }
        case "import-resumed":
            ImportComposerSheet(draft: .gallery) { _ in }
        case "import-quota-exhausted":
            ImportReviewSheet(galleryPhase: .quotaExhausted)
        case "import-premium-required":
            ImportReviewSheet(galleryPhase: .premiumRequired)
        default:
            ContentUnavailableView(
                "Écran inconnu : \(screen)",
                systemImage: "questionmark.square.dashed",
                description: Text("Écrans : cuisine, cuisine-recent, cuisine-search, cuisine-thermomix, cuisine-loading, recipe, recipe-thermomix, recipe-fresh, history, attempt, attempt-pending, execute, execute-thermomix, capture, proposal, proposal-thermomix, to-test, to-test-empty, recipe-edit, recipe-edit-thermomix, recipe-edit-oven, recipe-edit-oven-copy, recipe-edit-coffee, recipe-edit-fresh, improve, viewfinder, import-preview, import-preview-thermomix, ai-thinking, import-nothing-found, login, settings-data, quota, quota-premium, premium, premium-live, import-quota-exhausted, import-premium-required, import-resumed")
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
/// The oven section as the recipe sheet renders it once an oven is connected —
/// the settings plus the CTA, in its three states. Offline, hands-on: no server.
private struct OvenSectionGalleryScreen: View {
    var running: String?
    var isStarting = false
    /// The version bakes on one of the oven's own programmes: the mode row names the
    /// dish it runs, and the CTA gives way to what to select on the appliance.
    var assisted = false

    var body: some View {
        NavigationStack {
            List {
                OvenProfileSection(
                    item: assisted
                        ? .init(
                            program: "Quiche et tarte fine",
                            programIcon: "wand.and.stars",
                            temperature: "180 °C",
                            duration: "35 min"
                        )
                        : .init(
                            program: "Chaleur tournante",
                            programIcon: "fan",
                            temperature: "180 °C",
                            duration: "30 min"
                        ),
                    start: assisted
                        ? nil
                        : .init(running: running, isStarting: isStarting, onStart: {}),
                    onAppliance: assisted
                        ? "Sélectionne « Quiche et tarte fine » sur l’écran du four."
                        : nil
                )
            }
            .navigationTitle("Quiche fine")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The edit sheet over a fixture recipe, presented the way the menu presents it —
/// the sheet IS the screen here, so nothing is rendered under it.
private struct RecipeEditGalleryScreen: View {
    let recipe: Recipe
    let version: RecipeVersion
    /// What the connected oven is set to right now. nil is the ordinary case: no
    /// oven, no copy row.
    var applianceSettings: OvenSettings?

    var body: some View {
        Color.clear
            .sheet(isPresented: .constant(true)) {
                RecipeEditSheet(
                    initial: RecipeDraft(recipe: recipe, version: version),
                    versionNumber: version.number,
                    vocabulary: Fixtures.coffeeVocabulary,
                    applianceSettings: applianceSettings
                ) { _ in }
            }
    }
}

private struct RecipeDetailGalleryScreen: View {
    let recipe: Recipe
    /// When set, focuses that version (the attempt view: orange banner + change dots).
    let focusVersionNumber: Int?
    /// Opens straight on the delete dialog (version vs whole recipe).
    let startOnDeleteConfirm: Bool
    /// Opens straight on the copy prompt (the displayed version becomes a recipe).
    let startOnCopyPrompt: Bool
    @State private var path = NavigationPath()
    /// The flow's state, seeded with the fixture: offline, and shared with the
    /// version screens the sheets push, exactly as a tab shares it.
    @State private var store: RecipeStore

    init(
        recipe: Recipe,
        focusVersionNumber: Int? = nil,
        startOnDeleteConfirm: Bool = false,
        startOnCopyPrompt: Bool = false
    ) {
        self.recipe = recipe
        self.focusVersionNumber = focusVersionNumber
        self.startOnDeleteConfirm = startOnDeleteConfirm
        self.startOnCopyPrompt = startOnCopyPrompt
        self._store = State(initialValue: RecipeStore(previewRecipe: recipe))
    }

    var body: some View {
        NavigationStack(path: $path) {
            RecipeDetailView(
                previewRecipe: recipe,
                store: store,
                path: $path,
                focusVersionNumber: focusVersionNumber,
                startOnDeleteConfirm: startOnDeleteConfirm,
                startOnCopyPrompt: startOnCopyPrompt
            )
            .recipeFlow(store: store, path: $path, onReload: {}, onDelete: { _ in }, onDeleteVersion: { _, _ in })
        }
    }
}

/// The notebook tab with its sectioned library — needs local state for the sort, so
/// it lives in its own view. Opens filed by course, as the app does, the rows in the
/// order the server hands them (favourites first, then by best rating); the sort
/// picker is live, so both section axes (course, month) are reachable. `refreshing`
/// and `refreshFailed` show what a relaunch looks like: the cached library readable
/// with the spinner row leading it, and the same rows when the refresh never landed.
private struct CuisineGalleryScreen: View {
    @State private var sort: RecipeSortOption
    @State private var searchText: String
    private let refreshing: Bool
    private let refreshFailed: Bool

    init(
        sort: RecipeSortOption = .dishCategory,
        searchText: String = "",
        refreshing: Bool = false,
        refreshFailed: Bool = false
    ) {
        self._sort = State(initialValue: sort)
        self._searchText = State(initialValue: searchText)
        self.refreshing = refreshing
        self.refreshFailed = refreshFailed
    }

    private let library = [
        LibraryRecipe(id: "boeuf", title: "Bœuf bourguignon", category: .main, favorite: true, versionCount: 4, toTestCount: 1, bestRating: 5, updatedAt: Date()),
        LibraryRecipe(id: "risotto", title: "Risotto au parmesan", category: .main, tags: [Tag(label: "Thermomix", icon: .thermomix)], favorite: false, versionCount: 3, toTestCount: 1, bestRating: 4, updatedAt: Date()),
        LibraryRecipe(id: "gratin", title: "Gratin dauphinois", category: .main, favorite: false, versionCount: 2, toTestCount: 0, bestRating: 3, updatedAt: Date().addingTimeInterval(-12 * 86_400)),
        LibraryRecipe(id: "curry", title: "Curry de pois chiches", category: .main, favorite: false, versionCount: 1, toTestCount: 0, bestRating: nil, updatedAt: Date().addingTimeInterval(-3 * 86_400)),
        LibraryRecipe(id: "veloute", title: "Velouté de courge", category: .soup, tags: [Tag(label: "Thermomix", icon: .thermomix)], favorite: true, versionCount: 1, toTestCount: 0, bestRating: nil, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
    ]

    var body: some View {
        NavigationStack {
            HomePage(
                library: library,
                libraryGrouping: sort == .lastModified ? .month : .course,
                libraryLoading: false,
                libraryRefreshing: refreshing,
                libraryRefreshFailed: refreshFailed,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: "Cuisine",
                sortOptions: RecipeSortOption.cooking,
                sort: $sort,
                facet: .course(selection: .constant(nil)),
                // The real matcher over the rows above, so typing in the gallery
                // searches for real.
                search: .init(
                    text: $searchText,
                    entries: searchText.isEmpty ? nil : LibraryIndexEntry.matching(
                        searchText,
                        in: library.map {
                            LibraryIndexEntry(id: $0.id, title: $0.title, category: $0.category, favorite: $0.favorite)
                        }
                    ),
                    loading: false
                ),
                onSettings: {}
            )
        }
    }
}

/// What a closed analysis hands back to the import: the text and the photos that
/// were sent, as JPEG data — the composer must reopen holding exactly this. Flat
/// colour swatches stand in for real photos.
extension ImportDraft {
    static var gallery: ImportDraft {
        let photos: [Data] = [UIColor.systemBrown, .systemTeal].compactMap { color in
            UIGraphicsImageRenderer(size: CGSize(width: 144, height: 144)).image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 144, height: 144))
            }
            .jpegData(compressionQuality: 0.8)
        }
        return ImportDraft(photos: photos, text: "Pour 4 personnes, cuisson au four à chaleur tournante.")
    }
}

/// The import composer, offline: the text and the attached photos that make one
/// import. Flat colour swatches stand in for real photos.
private struct ComposerGalleryScreen: View {
    @State private var text: String
    @State private var photos: [ImportComposer.Photo]
    private let flow: ImportFlow

    init(
        photoCount: Int = 2,
        text: String = "Pour 4 personnes, cuisson au four à chaleur tournante.",
        flow: ImportFlow = .cooking
    ) {
        self.flow = flow
        self._text = State(initialValue: text)
        self._photos = State(initialValue: (0..<photoCount).map { index in
            ImportComposer.Photo(id: UUID(), image: Self.swatch(index))
        })
    }

    private static func swatch(_ index: Int) -> UIImage {
        let colors: [UIColor] = [.systemBrown, .systemTeal, .systemIndigo]
        return UIGraphicsImageRenderer(size: CGSize(width: 144, height: 144)).image { context in
            colors[index % colors.count].setFill()
            context.fill(CGRect(x: 0, y: 0, width: 144, height: 144))
        }
    }

    var body: some View {
        ImportComposer(
            text: $text,
            flow: flow,
            photos: photos,
            remainingSlots: 6 - photos.count,
            isLoadingPhoto: false,
            onAddFromLibrary: {},
            onAddFromCamera: {},
            onRemove: { id in photos.removeAll { $0.id == id } },
            onCancel: {},
            onAnalyze: {}
        )
    }
}

/// The coffee tab, offline: the library grouped by brewing method, or by month
/// under the "Dernière modification" sort.
private struct CoffeeGalleryScreen: View {
    @State private var sort: RecipeSortOption

    init(sort: RecipeSortOption = .brewMethod) {
        self._sort = State(initialValue: sort)
    }

    var body: some View {
        NavigationStack {
            HomePage(
                library: Fixtures.coffeeRecipes,
                libraryGrouping: sort == .lastModified ? .month : .method,
                libraryLoading: false,
                libraryHasMore: false,
                libraryLoadMoreFailed: false,
                title: "Café",
                sortOptions: RecipeSortOption.coffee,
                sort: $sort,
                facet: .method(selection: .constant(nil)),
                search: .idle,
                onSettings: {}
            )
        }
    }
}
#endif
