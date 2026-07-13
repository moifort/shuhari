#if DEBUG
import Foundation

/// Deterministic domain fixtures shared by `#Preview`s and the debug gallery.
/// One realistic recipe per shape the UI must handle: a coffee mid-iteration,
/// a Thermomix dish with per-step machine settings, and the transient models
/// (proposal, trial, import analysis, home read model) around them.
enum Fixtures {
    static let date = Date(timeIntervalSince1970: 1_752_300_000)

    static let coffeeIngredients = [
        Ingredient(name: "Café en grains", quantity: "18,5 g"),
        Ingredient(name: "Eau", quantity: "36 g"),
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

    // MARK: - Espresso (cafe, pending v4, pending proposal on demand)

    static let espressoV3 = RecipeVersion(
        number: 3,
        change: "Mouture plus fine",
        why: "L’extraction coulait trop vite.",
        originKind: .aiProposal,
        originDetail: nil,
        changedKeys: ["Mouture"],
        params: [
            Param(key: "Dose", value: "18,5 g"),
            Param(key: "Température", value: "93 °C"),
            Param(key: "Mouture", value: "2,0"),
            Param(key: "Sortie", value: "36 g"),
            Param(key: "Durée", value: "27 s"),
        ],
        ingredients: coffeeIngredients,
        steps: ["Purger le groupe.", "Distribuer, tasser à niveau.", "Extraire 36 g en 27 s."],
        tmxSteps: nil,
        averageNote: 7.5,
        trialCount: 2,
        createdAt: date.addingTimeInterval(-86_400 * 6)
    )

    static let espressoV4 = RecipeVersion(
        number: 4,
        change: "Température 93 → 92 °C",
        why: "Le creux en milieu de bouche pointe vers une extraction trop chaude.",
        originKind: .aiProposal,
        originDetail: nil,
        changedKeys: ["Température"],
        params: [
            Param(key: "Dose", value: "18,5 g"),
            Param(key: "Température", value: "92 °C"),
            Param(key: "Mouture", value: "2,0"),
            Param(key: "Sortie", value: "36 g"),
            Param(key: "Durée", value: "27 s"),
        ],
        ingredients: coffeeIngredients,
        steps: ["Purger le groupe.", "Distribuer, tasser à niveau.", "Extraire 36 g en 27 s."],
        tmxSteps: nil,
        averageNote: nil,
        trialCount: 0,
        createdAt: date.addingTimeInterval(-86_400)
    )

    static let espressoTrials = [
        Trial(
            id: "t2", recipeId: "espresso", versionNumber: 3, note: 8,
            remarks: "Équilibré, chocolat noir, belle longueur.",
            realParams: [], photoUrl: nil,
            executedAt: date.addingTimeInterval(-86_400 * 2)
        ),
        Trial(
            id: "t1", recipeId: "espresso", versionNumber: 3, note: 7,
            remarks: "Un peu court en sucrosité, température réelle 94 °C.",
            realParams: [Param(key: "Température", value: "94 °C")], photoUrl: nil,
            executedAt: date.addingTimeInterval(-86_400 * 4)
        ),
    ]

    static let espresso = Recipe(
        id: "espresso",
        title: "Espresso — Brésil Santa Lúcia",
        subtitle: "Torréfaction claire, panier 18 g",
        type: .cafe,
        createdAt: date.addingTimeInterval(-86_400 * 30),
        updatedAt: date,
        currentVersion: espressoV3,
        toTest: espressoV4,
        versions: [espressoV1, espressoV2, espressoV3, espressoV4],
        trials: espressoTrials,
        variations: [
            RecipeRef(id: "deca", title: "Espresso — déca", type: .cafe, subtitle: nil, currentVersionNumber: 1, averageNote: 6.5),
        ],
        derivedFrom: nil,
        pendingProposal: nil
    )

    static let espressoV1 = RecipeVersion(
        number: 1, change: nil, why: nil, originKind: .import,
        originDetail: "Importée par photo",
        changedKeys: [],
        params: [
            Param(key: "Dose", value: "18 g"),
            Param(key: "Température", value: "93 °C"),
            Param(key: "Mouture", value: "2,4"),
            Param(key: "Sortie", value: "36 g"),
            Param(key: "Durée", value: "25 s"),
        ],
        ingredients: coffeeIngredients,
        steps: ["Purger le groupe.", "Distribuer, tasser à niveau.", "Extraire 36 g en 25 s."],
        tmxSteps: nil, averageNote: 6.0, trialCount: 1,
        createdAt: date.addingTimeInterval(-86_400 * 30)
    )

    static let espressoV2 = RecipeVersion(
        number: 2, change: "Dose 18 → 18,5 g", why: "Corps un peu maigre.",
        originKind: .aiProposal, originDetail: nil,
        changedKeys: ["Dose"],
        params: [
            Param(key: "Dose", value: "18,5 g"),
            Param(key: "Température", value: "93 °C"),
            Param(key: "Mouture", value: "2,4"),
            Param(key: "Sortie", value: "36 g"),
            Param(key: "Durée", value: "25 s"),
        ],
        ingredients: coffeeIngredients,
        steps: ["Purger le groupe.", "Distribuer, tasser à niveau.", "Extraire 36 g en 25 s."],
        tmxSteps: nil, averageNote: 6.5, trialCount: 1,
        createdAt: date.addingTimeInterval(-86_400 * 20)
    )

    // MARK: - Risotto (tmx, per-step machine settings)

    static let risottoV2 = RecipeVersion(
        number: 2,
        change: "Bouillon 700 → 650 ml",
        why: "Trop liquide en fin de cuisson.",
        originKind: .aiProposal,
        originDetail: nil,
        changedKeys: [],
        params: [],
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
        averageNote: 7.0,
        trialCount: 1,
        createdAt: date.addingTimeInterval(-86_400 * 3)
    )

    static let risotto = Recipe(
        id: "risotto",
        title: "Risotto au parmesan",
        subtitle: "Thermomix TM6",
        type: .tmx,
        createdAt: date.addingTimeInterval(-86_400 * 12),
        updatedAt: date,
        currentVersion: risottoV2,
        toTest: nil,
        versions: [risottoV2],
        trials: [
            Trial(
                id: "rt1", recipeId: "risotto", versionNumber: 2, note: 7,
                remarks: "Bonne texture, manque un peu de sel.",
                realParams: [], photoUrl: nil,
                executedAt: date.addingTimeInterval(-86_400 * 2)
            ),
        ],
        variations: [],
        derivedFrom: nil,
        pendingProposal: nil
    )

    // MARK: - Transient models

    static let proposal = Proposal(
        recipeId: "espresso",
        versionNumber: 3,
        recommendation: .iteration,
        vars: [ProposalVar(key: "Température", from: "93 °C", to: "92 °C")],
        rationale: "Le léger creux en milieu de bouche pointe vers une extraction trop chaude ; un degré de moins devrait préserver la sucrosité.",
        queued: ["Essayer une pré-infusion de 5 s", "Passer la sortie à 38 g"],
        variation: VariationSuggestion(
            title: "Espresso — Brésil allongé",
            description: "Même café, ratio poussé pour un allongé doux."
        ),
        createdAt: date
    )

    static let importAnalysis = ImportAnalysis(
        title: "Cookies aux noix de pécan",
        subtitle: nil,
        type: .plat,
        params: [
            Param(key: "Four", value: "180 °C"),
            Param(key: "Cuisson", value: "12 min"),
        ],
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
        params: [],
        ingredients: risottoIngredients,
        steps: risottoV2.steps,
        tmxSteps: risottoV2.tmxSteps,
        sourceLabel: "Photo du livre Thermomix"
    )

    static let homeData = HomeData(
        toTest: [
            HomeTestItem(
                id: "espresso", title: "Espresso — Brésil Santa Lúcia", type: .cafe,
                versionNumber: 4, change: "Température 93 → 92 °C",
                why: "Le creux en milieu de bouche pointe vers une extraction trop chaude."
            ),
        ],
        library: [
            LibraryRecipe(id: "espresso", title: "Espresso — Brésil Santa Lúcia", type: .cafe, currentVersionNumber: 3, averageNote: 7.5, toTestNumber: 4, isDerived: false),
            LibraryRecipe(id: "deca", title: "Espresso — déca", type: .cafe, currentVersionNumber: 1, averageNote: 6.5, toTestNumber: nil, isDerived: true),
            LibraryRecipe(id: "risotto", title: "Risotto au parmesan", type: .tmx, currentVersionNumber: 2, averageNote: 7.0, toTestNumber: nil, isDerived: false),
            LibraryRecipe(id: "negroni", title: "Negroni blanc", type: .cocktail, currentVersionNumber: 1, averageNote: 6.0, toTestNumber: nil, isDerived: false),
        ],
        recentTrials: espressoTrials
    )
}
#endif
