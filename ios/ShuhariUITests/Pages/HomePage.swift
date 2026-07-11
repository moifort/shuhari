import XCTest

@MainActor
struct HomePage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Carnet"].waitOrFail()
        return self
    }

    func verifyRecipeVisible(_ title: String) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", title)
        let match = app.staticTexts.matching(predicate).firstMatch
        if !match.waitForExistence(timeout: 5) {
            try app.buttons.matching(predicate).firstMatch.waitOrFail(timeout: 3, "'\(title)' not found on home")
        }
    }

    @discardableResult
    func openRecipe(_ title: String) throws -> RecipeDetailPage {
        let predicate = NSPredicate(format: "label CONTAINS %@", title)
        try app.buttons.matching(predicate).firstMatch.tapOrFail()
        return RecipeDetailPage(app: app)
    }

    func openSettings() throws {
        try app.buttons["home-settings-button"].tapOrFail()
    }
}
