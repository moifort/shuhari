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

// MARK: - Draft

/// An ephemeral AI draft of the next version of a recipe. Generated on demand,
/// held in memory and never persisted: it carries the COMPLETE next version
/// (ingredients + steps + tmxSteps) plus a short human summary of what changed.
struct Draft: Sendable {
    let versionNumber: Int
    /// A short human summary of what the next version changes.
    let changeSummary: String
    let rationale: String
    /// The full ingredient list of the drafted next version.
    let ingredients: [Ingredient]
    /// The full step list of the drafted next version.
    let steps: [String]
    /// Per-step Thermomix settings aligned with `steps` (nil = plain step; empty
    /// when not a Thermomix recipe).
    let tmxSteps: [TmxSettings?]
}

/// The complete next-version draft handed back from the draft screen and sent to
/// `acceptDraft`. Full-replacement semantics — the lists are complete, not partial;
/// `changeSummary` and `rationale` carry through from the AI draft unchanged.
struct DraftEdit: Sendable {
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
    /// The current reproducible reference version.
    let currentVersion: RecipeVersion?
    /// The pending version awaiting a trial, if any.
    let toTest: RecipeVersion?
    /// The full lineage, oldest first.
    let versions: [RecipeVersion]
    /// The versions awaiting an essai (server-ordered, descending number). Empty
    /// when the recipe has only its original version.
    let pendingEssais: [RecipeVersion]

    /// The version number the next iteration would take.
    var nextVersionNumber: Int { (versions.map(\.number).max() ?? 0) + 1 }

    /// The essai journal: every tried version, most recent first.
    var essais: [RecipeVersion] {
        versions
            .filter(\.tried)
            .sorted { ($0.executedAt ?? .distantPast) > ($1.executedAt ?? .distantPast) }
    }

    /// The version the fiche presents as its reference — "la mieux notée": the
    /// tried version with the highest note. Falls back to the current reference,
    /// then the pending version, then the highest-numbered version, so a
    /// never-tried recipe (currentVersion == nil) still renders a fiche and keeps
    /// its record CTA.
    var bestRatedVersion: RecipeVersion? {
        versions
            .filter { $0.note != nil }
            // On a tie, favour the more recent version (higher number).
            .max { ($0.note ?? 0, $0.number) < ($1.note ?? 0, $1.number) }
            ?? currentVersion
            ?? toTest
            ?? versions.max { $0.number < $1.number }
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
