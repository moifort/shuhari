import XCTest

/// The AI proposition screen shown after an essai with written remarks: the
/// proposed next version, editable inline, with Fermer (discard) / Valider (accept).
@MainActor
struct PropositionPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["validate-proposition-button"].waitOrFail(timeout: 15)
        return self
    }

    /// Accept the proposition — appends the new version at the end of the lineage.
    func validate() throws {
        try app.buttons["validate-proposition-button"].tapOrFail()
    }

    /// Discard the proposition — nothing is persisted.
    func close() throws {
        try app.buttons["close-proposition-button"].tapOrFail()
    }
}
