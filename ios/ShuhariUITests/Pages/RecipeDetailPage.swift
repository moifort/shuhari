import XCTest

@MainActor
struct RecipeDetailPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["recipe-menu"].waitOrFail()
        return self
    }

    func verifyTitle(_ title: String) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", title)
        try app.staticTexts.matching(predicate).firstMatch.waitOrFail(timeout: 4, "recipe title '\(title)' not shown")
    }

    /// A pending version surfaces the "À tester" CTA in the bottom bar.
    func verifyPendingVersion(_ number: Int) throws {
        try app.buttons["to-test-button"].waitOrFail(timeout: 6, "pending v\(number) CTA not shown")
    }

    /// Record a trial for the displayed version via the round centre CTA — the
    /// way to run a first trial on a freshly imported recipe.
    @discardableResult
    func recordTrial() throws -> CapturePage {
        try app.buttons["record-trial-button"].tapOrFail()
        return CapturePage(app: app)
    }

    /// Open the "à tester" sheet and start the trial capture for the pending version.
    @discardableResult
    func openToTest(_ number: Int) throws -> CapturePage {
        try app.buttons["to-test-button"].tapOrFail()
        try app.buttons["execute-v\(number)-button"].tapOrFail()
        return CapturePage(app: app)
    }
}
