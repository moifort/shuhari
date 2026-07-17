import XCTest

@MainActor
struct DraftPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["validate-draft-button"].waitOrFail(timeout: 15)
        return self
    }

    func validate() throws {
        try app.buttons["validate-draft-button"].tapOrFail()
    }

    func close() throws {
        try app.buttons["close-draft-button"].tapOrFail()
    }
}
