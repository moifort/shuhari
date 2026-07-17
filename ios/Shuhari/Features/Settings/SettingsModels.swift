import Foundation

/// One version section of the application changelog.
struct ChangelogVersion: Identifiable, Sendable {
    let version: String
    let date: Date?
    let notes: [String]

    var id: String { version }
}

/// Number of records restored by an import.
struct ImportSummary: Sendable {
    let recipes: Int
    let versions: Int

    var totalRecords: Int { recipes + versions }
}
