import XCTest

@MainActor
struct ExecutePage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["execute-done-button"].waitOrFail()
        return self
    }

    @discardableResult
    func done() throws -> CapturePage {
        try app.buttons["execute-done-button"].tapOrFail()
        return CapturePage(app: app)
    }
}
