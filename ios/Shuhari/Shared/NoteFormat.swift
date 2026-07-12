import Foundation

/// Formats trial notes the way the app speaks them: French decimal, "7,5/10".
/// The UI copy is French by design, so the locale is pinned rather than
/// inherited from the device.
enum NoteFormat {
    private static let locale = Locale(identifier: "fr_FR")

    /// "7,5" — the bare figure, for layouts that style the "/10" separately.
    static func bare(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// "7,5/10"
    static func average(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale)))/10"
    }

    /// "7,5/10 moy."
    static func averageWithSuffix(_ value: Double) -> String {
        "\(average(value)) moy."
    }
}
