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

/// An immutable entry in a recipe's linear lineage (v1 → v2 → …). A version is
/// its ingredients + steps (+ per-step Thermomix settings) — no parameters.
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
    let averageNote: Double?
    let trialCount: Int
    let createdAt: Date

    var id: Int { number }
}

// MARK: - Trial

/// One execution of a recipe version.
struct Trial: Identifiable, Sendable {
    let id: String
    let recipeId: String
    let versionNumber: Int
    let note: Int
    let remarks: String
    let photoUrl: String?
    let executedAt: Date
}

// MARK: - Proposal

/// An AI proposal for the next version of a recipe (presence == pending). It
/// carries the COMPLETE draft of version n+1 (ingredients + steps + tmxSteps)
/// plus a short human summary of what changed.
struct Proposal: Sendable {
    let recipeId: String
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
    let createdAt: Date
}

/// An edited next-version draft handed back from the proposal screen. It FULLY
/// REPLACES the AI draft on accept — the lists are complete, not partial.
struct ProposalDraft: Sendable {
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
    /// The trial journal, most recent first.
    let trials: [Trial]
    /// The AI proposal awaiting a decision, if any.
    let pendingProposal: Proposal?

    /// The version number the next iteration would take.
    var nextVersionNumber: Int { (versions.map(\.number).max() ?? 0) + 1 }

    /// The version the fiche presents as its reference — "la mieux notée": the
    /// tried version with the highest average note, falling back to the current
    /// reference when nothing has been rated yet.
    var bestRatedVersion: RecipeVersion? {
        versions
            .filter { $0.averageNote != nil }
            // On a tie, favour the more recent version (higher number).
            .max { ($0.averageNote ?? 0, $0.number) < ($1.averageNote ?? 0, $1.number) }
            ?? currentVersion
    }

    /// Mean note over every trial of the recipe, all versions combined.
    var overallAverageNote: Double? {
        guard !trials.isEmpty else { return nil }
        let sum = trials.reduce(0) { $0 + $1.note }
        return Double(sum) / Double(trials.count)
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
