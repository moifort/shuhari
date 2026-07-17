import XCTest

@MainActor
struct ProposalPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["validate-proposal-button"].waitOrFail(timeout: 15)
        return self
    }

    func validate() throws {
        try app.buttons["validate-proposal-button"].tapOrFail()
    }

    func refuse() throws {
        try app.buttons["refuse-proposal-button"].tapOrFail()
    }
}
