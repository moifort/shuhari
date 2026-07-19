import Foundation

/// Formats attempt ratings the way the app speaks them: French decimal, "3,5/5".
/// The UI copy is French by design, so the locale is pinned rather than
/// inherited from the device.
enum RatingFormat {
    private static let locale = Locale(identifier: "fr_FR")

    /// "3,5" — the bare figure, for layouts that style the "/5" separately.
    static func bare(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// "3,5/5"
    static func average(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale)))/5"
    }

    /// "3,5/5 moy."
    static func averageWithSuffix(_ value: Double) -> String {
        "\(average(value)) moy."
    }
}
