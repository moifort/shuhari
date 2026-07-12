import Foundation

/// Shared domain models for the experimentation loop. Sendable value types,
/// decoupled from the generated `ShuhariGraphQL` selection sets so that views,
/// previews and tests never depend on Apollo. Mapping from generated types lives
/// in each feature's `*API.swift`.

// MARK: - Param

/// A single recipe parameter (ordered list preserves display order).
struct Param: Identifiable, Sendable, Hashable {
    let key: String
    let value: String
    var id: String { key }
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

/// An immutable entry in a recipe's linear lineage (v1 → v2 → …).
struct RecipeVersion: Identifiable, Sendable {
    let number: Int
    let change: String?
    let why: String?
    let originKind: VersionOriginKind
    let originDetail: String?
    let changedKeys: [String]
    let params: [Param]
    let steps: [String]
    /// Per-step Thermomix settings, aligned with `steps` (nil entry = plain step).
    /// nil for non-Thermomix recipes and versions imported before extraction existed.
    let tmxSteps: [TmxSettings?]?
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
    /// Only the parameters that deviated from the version's targets.
    let realParams: [Param]
    let photoUrl: String?
    let executedAt: Date
}

// MARK: - Proposal

/// Whether the AI recommends iterating the recipe or spinning off a variation.
enum ProposalRecommendation: Sendable, Equatable {
    case iteration
    case variation
}

/// A single proposed parameter change.
struct ProposalVar: Identifiable, Sendable {
    let key: String
    let from: String?
    let to: String
    var id: String { key }
}

/// A suggested name and description when the AI recommends a variation.
struct VariationSuggestion: Sendable {
    let title: String
    let description: String
}

/// An AI proposal for the next step of a recipe (presence == pending).
struct Proposal: Sendable {
    let recipeId: String
    let versionNumber: Int
    let recommendation: ProposalRecommendation
    let vars: [ProposalVar]
    let rationale: String
    let queued: [String]
    let variation: VariationSuggestion?
    let createdAt: Date
}

// MARK: - Recipe

/// A lightweight reference to another recipe (parent or variation).
struct RecipeRef: Identifiable, Sendable {
    let id: String
    let title: String
    let type: RecipeType
    let subtitle: String?
    let currentVersionNumber: Int?
    let averageNote: Double?
}

/// A recipe under experimentation, with its version lineage.
struct Recipe: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let type: RecipeType
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
    /// Recipes derived from this one.
    let variations: [RecipeRef]
    /// The parent recipe when this is a variation.
    let derivedFrom: RecipeRef?
    /// The AI proposal awaiting a decision, if any.
    let pendingProposal: Proposal?

    /// The version number the next iteration would take.
    var nextVersionNumber: Int { (versions.map(\.number).max() ?? 0) + 1 }

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
    var params: [Param]
    var steps: [String]
    /// Per-step Thermomix settings, aligned with `steps` (nil entry = plain step).
    var tmxSteps: [TmxSettings?]? = nil
    var sourceLabel: String?
}
