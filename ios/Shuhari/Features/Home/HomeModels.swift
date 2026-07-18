import Foundation

/// A library row: how many versions the recipe has and its best essai note ("the
/// highest star" across every version it ever cooked).
struct LibraryRecipe: Identifiable, Sendable {
    let id: String
    let title: String
    let type: RecipeType
    let category: DishCategory
    let versionCount: Int
    let bestNote: Int?
    let updatedAt: Date
}

/// One month's worth of library recipes — the library is grouped by the month of
/// each recipe's last update (e.g. "Juillet 2026") instead of by type.
struct LibraryMonthGroup: Identifiable, Sendable {
    /// A sortable `yyyy-MM` key that also identifies the section.
    let id: String
    let label: String
    let recipes: [LibraryRecipe]

    /// Group accumulated (already server-sorted) recipes by the month of their last
    /// update — most recent month first, and within a month the most recently updated
    /// first. Used by the paginated library when sorted by "Dernière modification".
    static func grouping(_ recipes: [LibraryRecipe]) -> [LibraryMonthGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: recipes) { recipe in
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
