#if DEBUG
import Foundation

/// Deterministic domain fixtures shared by `#Preview`s and the debug gallery.
/// One realistic recipe per shape the UI must handle: a plated dish mid-iteration
/// (Bœuf bourguignon), a Thermomix dish with per-step machine settings (Risotto),
/// and the transient models (draft, trial, import analysis, home read model)
/// around them. Cuisine-only — no params, no café/cocktail.
enum Fixtures {
    static let date = Date(timeIntervalSince1970: 1_752_300_000)

    static let bourguignonIngredients = [
        Ingredient(name: "Bœuf (paleron)", quantity: "1,2 kg"),
        Ingredient(name: "Lardons", quantity: "200 g"),
        Ingredient(name: "Oignons", quantity: "2"),
        Ingredient(name: "Carottes", quantity: "3"),
        Ingredient(name: "Vin rouge", quantity: "75 cl"),
        Ingredient(name: "Bouillon", quantity: "50 cl"),
        Ingredient(name: "Farine", quantity: "30 g"),
        Ingredient(name: "Bouquet garni", quantity: "1"),
    ]

    static let bourguignonSteps = [
        "Saisir le bœuf sur toutes les faces, réserver.",
        "Faire revenir lardons, oignons et carottes.",
        "Singer avec la farine, mélanger.",
        "Mouiller au vin et au bouillon, ajouter le bouquet garni.",
        "Cuire à couvert 3 h.",
    ]

    static let risottoIngredients = [
        Ingredient(name: "Oignon", quantity: "1"),
        Ingredient(name: "Ail", quantity: "1 gousse"),
        Ingredient(name: "Huile d’olive", quantity: "20 g"),
        Ingredient(name: "Riz arborio", quantity: "320 g"),
        Ingredient(name: "Vin blanc", quantity: "60 ml"),
        Ingredient(name: "Bouillon", quantity: "650 ml"),
        Ingredient(name: "Parmesan", quantity: "60 g"),
    ]

    // MARK: - Bœuf bourguignon (plat, pending v4)

    static let bourguignonV1 = RecipeVersion(
        number: 1, change: nil, why: nil, originKind: .import,
        originDetail: "Importée par photo",
        ingredients: bourguignonIngredients,
        steps: bourguignonSteps,
        tmxSteps: [], averageNote: 3.0, trialCount: 1,
        createdAt: date.addingTimeInterval(-86_400 * 30)
    )

    static let bourguignonV2 = RecipeVersion(
        number: 2, change: "Ajout d’un bouquet garni", why: "Manque d’arômes.",
        originKind: .aiProposal, originDetail: nil,
        ingredients: bourguignonIngredients,
        steps: bourguignonSteps,
        tmxSteps: [], averageNote: 3.5, trialCount: 1,
        createdAt: date.addingTimeInterval(-86_400 * 20)
    )

    static let bourguignonV3 = RecipeVersion(
        number: 3,
        change: "Vin rouge 50 → 75 cl",
        why: "La sauce manquait de corps.",
        originKind: .aiProposal,
        originDetail: nil,
        ingredients: bourguignonIngredients,
        steps: bourguignonSteps,
        tmxSteps: [],
        averageNote: 4.0,
        trialCount: 2,
        createdAt: date.addingTimeInterval(-86_400 * 6)
    )

    static let bourguignonV4 = RecipeVersion(
        number: 4,
        change: "Cuisson 3 h → 3 h 30",
        why: "Viande encore un peu ferme.",
        originKind: .aiProposal,
        originDetail: nil,
        ingredients: bourguignonIngredients,
        steps: bourguignonSteps,
        tmxSteps: [],
        averageNote: nil,
        trialCount: 0,
        createdAt: date.addingTimeInterval(-86_400)
    )

    static let bourguignonTrials = [
        Trial(
            id: "t2", recipeId: "bourguignon", versionNumber: 3, note: 4,
            remarks: "Sauce nappante, viande fondante.", photoUrl: nil,
            executedAt: date.addingTimeInterval(-86_400 * 2)
        ),
        Trial(
            id: "t1", recipeId: "bourguignon", versionNumber: 3, note: 4,
            remarks: "Très bon, un peu ferme par endroits.", photoUrl: nil,
            executedAt: date.addingTimeInterval(-86_400 * 4)
        ),
    ]

    static let bourguignon = Recipe(
        id: "bourguignon",
        title: "Bœuf bourguignon",
        subtitle: "Mijoté au vin rouge",
        type: .plat,
        category: .plat,
        createdAt: date.addingTimeInterval(-86_400 * 30),
        updatedAt: date,
        currentVersion: bourguignonV3,
        toTest: bourguignonV4,
        versions: [bourguignonV1, bourguignonV2, bourguignonV3, bourguignonV4],
        trials: bourguignonTrials
    )

    // MARK: - Risotto (tmx, per-step machine settings)

    static let risottoV2 = RecipeVersion(
        number: 2,
        change: "Bouillon 700 → 650 ml",
        why: "Trop liquide en fin de cuisson.",
        originKind: .aiProposal,
        originDetail: nil,
        ingredients: risottoIngredients,
        steps: [
            "Mettre l’oignon et l’ail dans le bol, mixer.",
            "Ajouter l’huile d’olive, faire revenir.",
            "Ajouter le riz et le vin, cuire sans le gobelet doseur.",
            "Ajouter le bouillon, cuire.",
            "Ajouter le parmesan, mélanger, laisser reposer 2 min.",
        ],
        tmxSteps: [
            TmxSettings(time: "5 s", temperature: nil, speed: "5", reverse: false),
            TmxSettings(time: "3 min", temperature: "120 °C", speed: "1", reverse: false),
            TmxSettings(time: "2 min", temperature: "100 °C", speed: "1", reverse: true),
            TmxSettings(time: "14 min", temperature: "100 °C", speed: "1", reverse: true),
            nil,
        ],
        averageNote: 3.5,
        trialCount: 1,
        createdAt: date.addingTimeInterval(-86_400 * 3)
    )

    static let risotto = Recipe(
        id: "risotto",
        title: "Risotto au parmesan",
        subtitle: "Thermomix TM6",
        type: .tmx,
        category: .plat,
        createdAt: date.addingTimeInterval(-86_400 * 12),
        updatedAt: date,
        currentVersion: risottoV2,
        toTest: nil,
        versions: [risottoV2],
        trials: [
            Trial(
                id: "rt1", recipeId: "risotto", versionNumber: 2, note: 4,
                remarks: "Bonne texture, manque un peu de sel.", photoUrl: nil,
                executedAt: date.addingTimeInterval(-86_400 * 2)
            ),
        ]
    )

    // MARK: - Transient models

    /// The full draft of v5: the base v4 lists with a longer cooking time and a
    /// touch less bouillon — a couple of rows differ from the base for the diff.
    static let draft = Draft(
        versionNumber: 4,
        changeSummary: "Bouillon 50 → 40 cl, cuisson 3 h 30 → 4 h",
        rationale: "La sauce reste un peu liquide et la viande gagnerait à confire plus longtemps ; réduire le bouillon et allonger la cuisson devrait concentrer les arômes.",
        ingredients: [
            Ingredient(name: "Bœuf (paleron)", quantity: "1,2 kg"),
            Ingredient(name: "Lardons", quantity: "200 g"),
            Ingredient(name: "Oignons", quantity: "2"),
            Ingredient(name: "Carottes", quantity: "3"),
            Ingredient(name: "Vin rouge", quantity: "75 cl"),
            Ingredient(name: "Bouillon", quantity: "40 cl"),
            Ingredient(name: "Farine", quantity: "30 g"),
            Ingredient(name: "Bouquet garni", quantity: "1"),
        ],
        steps: [
            "Saisir le bœuf sur toutes les faces, réserver.",
            "Faire revenir lardons, oignons et carottes.",
            "Singer avec la farine, mélanger.",
            "Mouiller au vin et au bouillon, ajouter le bouquet garni.",
            "Cuire à couvert 4 h.",
        ],
        tmxSteps: []
    )

    static let importAnalysis = ImportAnalysis(
        title: "Cookies aux noix de pécan",
        subtitle: nil,
        type: .plat,
        category: .dessert,
        ingredients: [
            Ingredient(name: "Beurre", quantity: "170 g"),
            Ingredient(name: "Cassonade", quantity: "200 g"),
            Ingredient(name: "Farine", quantity: "280 g"),
            Ingredient(name: "Œuf", quantity: "1"),
            Ingredient(name: "Noix de pécan", quantity: "100 g"),
        ],
        steps: [
            "Crémer le beurre et la cassonade.",
            "Incorporer l’œuf puis les poudres.",
            "Ajouter les noix de pécan torréfiées.",
            "Cuire 12 min à 180 °C.",
        ],
        tmxSteps: nil,
        sourceLabel: "Photo du livre « Biscuits »"
    )

    static let importAnalysisTmx = ImportAnalysis(
        title: "Risotto au parmesan",
        subtitle: "Thermomix TM6",
        type: .tmx,
        category: .plat,
        ingredients: risottoIngredients,
        steps: risottoV2.steps,
        tmxSteps: risottoV2.tmxSteps,
        sourceLabel: "Photo du livre Thermomix"
    )

    static let homeData = HomeData(
        toTest: [
            HomeTestItem(
                id: "bourguignon", title: "Bœuf bourguignon", type: .plat, category: .plat,
                versionNumber: 4, change: "Cuisson 3 h → 3 h 30",
                why: "Viande encore un peu ferme."
            ),
        ],
        library: [
            LibraryRecipe(id: "bourguignon", title: "Bœuf bourguignon", type: .plat, category: .plat, versionCount: 4, bestNote: 5, averageNote: 4.0, updatedAt: Date()),
            LibraryRecipe(id: "joues", title: "Joues de bœuf confites", type: .plat, category: .plat, versionCount: 1, bestNote: 4, averageNote: 3.5, updatedAt: Date().addingTimeInterval(-3 * 86_400)),
            LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .tmx, category: .plat, versionCount: 2, bestNote: 4, averageNote: 3.5, updatedAt: Date().addingTimeInterval(-40 * 86_400)),
            LibraryRecipe(id: "veloute", title: "Velouté de courge", type: .tmx, category: .soupe, versionCount: 1, bestNote: nil, averageNote: 3.0, updatedAt: Date().addingTimeInterval(-45 * 86_400)),
        ],
        recentTrials: bourguignonTrials
    )
}
#endif
