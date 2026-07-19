import XCTest

/// The AI proposal screen shown after an attempt with written remarks: the
/// proposed next version, editable inline, with Fermer (discard) / Valider (accept).
@MainActor
struct ProposalPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["validate-proposal-button"].waitOrFail(timeout: 15)
        return self
    }

    /// Accept the proposal — appends the new version at the end of the lineage.
    func validate() throws {
        try app.buttons["validate-proposal-button"].tapOrFail()
    }

    /// Discard the proposal — nothing is persisted.
    func close() throws {
        try app.buttons["close-proposal-button"].tapOrFail()
    }
}
