import Foundation

/// Shared domain models for the experimentation loop. Sendable value types,
/// decoupled from the generated `ShuhariGraphQL` selection sets so that views,
/// previews and tests never depend on Apollo. Mapping from generated types lives
/// in each feature's `*API.swift`.

// MARK: - Ingredient

/// A recipe component with its measured quantity ("Riz" / "320 g"). The
/// shopping-list view of the recipe.
struct Ingredient: Identifiable, Sendable, Hashable {
    let name: String
    let quantity: String
    var id: String { name }
}

// MARK: - Thermomix

/// Thermomix settings for one step (display-oriented strings — "Varoma" and
/// "pétrin" are valid values, no computation is ever done on them).
struct TmxSettings: Sendable, Hashable {
    let time: String?
    let temperature: String?
    let speed: String?
    let reverse: Bool

    var isEmpty: Bool { time == nil && temperature == nil && speed == nil && !reverse }
}

// MARK: - Version

/// How a version came to exist.
enum VersionOriginKind: Sendable {
    case aiProposal
    case `import`
    case manual
}

/// An entry in a recipe's linear lineage (v1 → v2 → …). Its content (ingredients +
/// steps + per-step Thermomix settings) is immutable; its essai outcome (`note`,
/// `remarks`, `executedAt`, `photoUrl`) is written once, when the version is tried.
/// A version is an "essai à faire" until `executedAt != nil`.
struct RecipeVersion: Identifiable, Sendable {
    let number: Int
    /// The version this one iterates on — the attempt it was built from. nil on the
    /// original v1, which builds on nothing. Drives the essai-diff base.
    let basedOn: Int?
    let change: String?
    let why: String?
    let originKind: VersionOriginKind
    let originDetail: String?
    /// The recipe's components with quantities (empty when none/absent).
    let ingredients: [Ingredient]
    let steps: [String]
    /// Per-step Thermomix settings, aligned with `steps` (nil entry = plain step).
    /// Empty for non-Thermomix recipes — "is Thermomix" is derived from `type`.
    let tmxSteps: [TmxSettings?]
    /// The recipe this version belongs to.
    let recipeId: String
    /// The essai rating (1..5), or nil while the version hasn't been executed yet.
    let note: Int?
    /// The essai remarks, or nil while not yet executed.
    let remarks: String?
    /// When the essai was executed, or nil while still an "essai à faire".
    let executedAt: Date?
    /// Signed URL of the essai photo (nil until photo storage is provisioned).
    let photoUrl: String?
    let createdAt: Date

    var id: Int { number }

    /// Whether this version has been executed (its essai recorded).
    var tried: Bool { executedAt != nil }
}

// MARK: - Proposition

/// An ephemeral AI proposition for the next version of a recipe. Generated on
/// demand, held in memory and never persisted: it carries the COMPLETE next
/// version (ingredients + steps + tmxSteps) plus a short human summary of what
/// changed. `basedOn` is the version it iterates on (the one just cooked).
struct Proposition: Sendable {
    /// The version this proposition iterates on — echoed back on accept.
    let basedOn: Int
    /// A short human summary of what the next version changes.
    let changeSummary: String
    let rationale: String
    /// The full ingredient list of the proposed next version.
    let ingredients: [Ingredient]
    /// The full step list of the proposed next version.
    let steps: [String]
    /// Per-step Thermomix settings aligned with `steps` (nil = plain step; empty
    /// when not a Thermomix recipe).
    let tmxSteps: [TmxSettings?]
}

/// The complete next-version proposition handed back from the proposition screen
/// and sent to `acceptProposition`. Full-replacement semantics — the lists are
/// complete, not partial; `basedOn`, `changeSummary` and `rationale` carry through
/// from the AI proposition unchanged.
struct PropositionEdit: Sendable {
    let basedOn: Int
    let changeSummary: String
    let rationale: String
    let ingredients: [Ingredient]
    let steps: [String]
    let tmxSteps: [TmxSettings?]
}

// MARK: - Recipe

/// A recipe under experimentation, with its version lineage.
struct Recipe: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let type: RecipeType
    /// The dish course — fixed at import, shared across all versions.
    let category: DishCategory
    let createdAt: Date
    let updatedAt: Date
    /// The full lineage, oldest first.
    let versions: [RecipeVersion]
    /// The best rating across every executed version, computed server-side. nil
    /// when no version has been cooked yet. Drives the recipe's display note.
    let bestNote: Int?
    /// The version to show first when the fiche opens: the essai in progress (the
    /// most recent version built on the best-rated one), else that best-rated
    /// version, else the latest. Never nil — a recipe always has at least its v1.
    let versionToOpen: RecipeVersion

    /// The version number the next iteration would take.
    var nextVersionNumber: Int { (versions.map(\.number).max() ?? 0) + 1 }

    /// The essai journal: every tried version, most recent first.
    var essais: [RecipeVersion] {
        versions
            .filter(\.tried)
            .sorted { ($0.executedAt ?? .distantPast) > ($1.executedAt ?? .distantPast) }
    }

    /// Mean note over every essai of the recipe, all versions combined.
    var overallAverageNote: Double? {
        let notes = essais.compactMap(\.note)
        guard !notes.isEmpty else { return nil }
        return Double(notes.reduce(0, +)) / Double(notes.count)
    }

    func version(_ number: Int) -> RecipeVersion? {
        versions.first { $0.number == number }
    }
}

// MARK: - Import

/// Structured recipe extracted from an import source (editable preview).
struct ImportAnalysis: Sendable, Hashable {
    var title: String
    var subtitle: String?
    var type: RecipeType
    /// The dish course detected by the AI (editable before create).
    var category: DishCategory
    /// The recipe's components with quantities (empty when none).
    var ingredients: [Ingredient] = []
    var steps: [String]
    /// Per-step Thermomix settings, aligned with `steps` (nil entry = plain step).
    var tmxSteps: [TmxSettings?]? = nil
    var sourceLabel: String?
}
