import XCTest

@MainActor
struct ImportPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Importer"].waitOrFail()
        return self
    }

    @discardableResult
    func selectTextMode() throws -> Self {
        let picker = app.segmentedControls["import-mode-picker"]
        try picker.waitOrFail()
        picker.buttons["Texte"].tap()
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
