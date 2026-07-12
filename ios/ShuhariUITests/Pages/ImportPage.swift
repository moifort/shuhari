import XCTest

@MainActor
struct ImportPage {
    let app: XCUIApplication

    /// From the camera-first scan screen, open the text-entry sheet (the only
    /// import path exercisable on the simulator — no camera, out-of-process picker).
    @discardableResult
    func openTextEntry() throws -> Self {
        try app.buttons["import-text-button"].tapOrFail()
        return self
    }

    @discardableResult
    func typeRecipe(_ text: String) throws -> Self {
        let field = app.textViews["import-text-field"].exists ? app.textViews["import-text-field"] : app.textFields["import-text-field"]
        try field.tapOrFail()
        field.typeText(text)
        return self
    }

    @discardableResult
    func analyze() throws -> ImportPreviewPage {
        try app.buttons["analyze-button"].tapOrFail()
        return ImportPreviewPage(app: app)
    }
}

@MainActor
struct ImportPreviewPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        // The analysis overlay can take a few seconds (AI round-trip).
        try app.buttons["save-recipe-button"].waitOrFail(timeout: 20)
        return self
    }

    func verifyTitleField() throws {
        try app.textFields["import-title-field"].waitOrFail()
    }

    @discardableResult
    func save() throws -> RecipeDetailPage {
        try app.buttons["save-recipe-button"].tapOrFail()
        return RecipeDetailPage(app: app)
    }
}
