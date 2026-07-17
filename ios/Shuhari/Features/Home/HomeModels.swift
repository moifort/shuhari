import Foundation

/// A recipe with a pending version awaiting a trial — rendered as a "À tester" banner.
struct HomeTestItem: Identifiable, Sendable {
    let id: String
    let title: String
    let type: RecipeType
    let category: DishCategory
    let versionNumber: Int
    let change: String?
    let why: String?
}

/// A library row: how many versions the recipe has, its best trial note ("the
/// highest star"), the current reference's mean note, and whether it's a variation.
struct LibraryRecipe: Identifiable, Sendable {
    let id: String
    let title: String
    let type: RecipeType
    let category: DishCategory
    let versionCount: Int
    let bestNote: Int?
    let averageNote: Double?
    let isDerived: Bool
    let updatedAt: Date
}

/// One month's worth of library recipes — the library is grouped by the month of
/// each recipe's last update (e.g. "Juillet 2026") instead of by type.
struct LibraryMonthGroup: Identifiable, Sendable {
    /// A sortable `yyyy-MM` key that also identifies the section.
    let id: String
    let label: String
    let recipes: [LibraryRecipe]
}

/// The read model behind the home screen.
struct HomeData: Sendable {
    let toTest: [HomeTestItem]
    let library: [LibraryRecipe]
    let recentTrials: [Trial]

    /// The library grouped by the month of each recipe's last update — most recent
    /// month first, and within a month the most recently updated recipe first.
    func libraryByMonth() -> [LibraryMonthGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: library) { recipe in
            calendar.dateComponents([.year, .month], from: recipe.updatedAt)
        }
        return buckets
            .map { components, recipes in
                LibraryMonthGroup(
                    id: MonthLabel.id(components),
                    label: MonthLabel.of(components, calendar: calendar),
                    recipes: recipes.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { $0.id > $1.id }
    }

    /// Restrict every section to the given recipe types — backs the per-category tabs.
    func filtered(to types: Set<RecipeType>) -> HomeData {
        let lib = library.filter { types.contains($0.type) }
        let ids = Set(lib.map(\.id))
        return HomeData(
            toTest: toTest.filter { types.contains($0.type) },
            library: lib,
            recentTrials: recentTrials.filter { ids.contains($0.recipeId) }
        )
    }

    func title(forRecipe id: String) -> String {
        library.first { $0.id == id }?.title ?? "Recette"
    }
}

/// Formats a month bucket as a French section title ("Juillet 2026") and a
/// sortable key ("2026-07").
enum MonthLabel {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    static func id(_ components: DateComponents) -> String {
        String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    static func of(_ components: DateComponents, calendar: Calendar) -> String {
        guard let date = calendar.date(from: components) else { return "" }
        return formatter.string(from: date).localizedCapitalized
    }
}
