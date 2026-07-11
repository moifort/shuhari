import XCTest

@MainActor
struct CapturePage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["save-trial-button"].waitOrFail()
        return self
    }

    @discardableResult
    func pickNote(_ value: Int) throws -> Self {
        try app.buttons["note-\(value)"].tapOrFail()
        return self
    }

    @discardableResult
    func typeRemarks(_ text: String) throws -> Self {
        let field = app.textViews["remarks-field"].exists ? app.textViews["remarks-field"] : app.textFields["remarks-field"]
        try field.tapOrFail()
        field.typeText(text)
        return self
    }

    func save() throws {
        try app.buttons["save-trial-button"].tapOrFail()
    }
}
