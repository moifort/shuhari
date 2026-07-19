import Foundation

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
