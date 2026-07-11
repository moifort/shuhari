import XCTest

@MainActor
struct RecipeDetailPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["execute-current-button"].waitOrFail()
        return self
    }

    func verifyTitle(_ title: String) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", title)
        try app.staticTexts.matching(predicate).firstMatch.waitOrFail(timeout: 4, "recipe title '\(title)' not shown")
    }

    /// A pending version banner shows an "Exécuter la vN" button.
    func verifyPendingVersion(_ number: Int) throws {
        try app.buttons["execute-v\(number)-button"].waitOrFail(timeout: 6, "pending v\(number) banner not shown")
    }

    @discardableResult
    func executeCurrent() throws -> ExecutePage {
        try app.buttons["execute-current-button"].tapOrFail()
        return ExecutePage(app: app)
    }

    @discardableResult
    func executePending(_ number: Int) throws -> ExecutePage {
        try app.buttons["execute-v\(number)-button"].tapOrFail()
        return ExecutePage(app: app)
    }
}
