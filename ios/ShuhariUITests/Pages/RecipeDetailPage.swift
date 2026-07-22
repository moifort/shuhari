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

    /// The recipe sheet opens on a server-derived version; its header badge carries a
    /// "Version N" accessibility label. Any version is cookable and there is no
    /// promotion — a freshly appended version simply becomes the one the recipe sheet shows.
    func verifyVersion(_ number: Int) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", "Version \(number)")
        try app.descendants(matching: .any).matching(predicate).firstMatch
            .waitOrFail(timeout: 6, "version v\(number) badge not shown")
    }

    /// Record an attempt on the displayed version via the round centre CTA. Every
    /// version is cookable and an attempt is overwritable, so this is always available.
    @discardableResult
    func recordAttempt() throws -> CapturePage {
        try app.buttons["record-attempt-button"].tapOrFail()
        return CapturePage(app: app)
    }

    // MARK: - Ingredient scaling

    /// The displayed quantity of the ingredient at `index` in the shopping list.
    func ingredientQuantity(_ index: Int) -> XCUIElement {
        app.staticTexts["ingredient-quantity-\(index)"]
    }

    /// One −/+ tick on the ingredient at `index`. The stepper's inner buttons carry
    /// system labels (locale-dependent), so fall back on their order: minus left,
    /// plus right.
    func stepIngredient(_ index: Int, down: Bool) throws {
        let stepper = try app.steppers["ingredient-stepper-\(index)"].waitOrFail()
        let label = down ? "Decrement" : "Increment"
        let button = stepper.buttons[label].exists
            ? stepper.buttons[label]
            : stepper.buttons.element(boundBy: down ? 0 : 1)
        try button.tapOrFail()
    }

    /// Drop the ephemeral scaling — back to the stored quantities.
    func resetScaling() throws {
        try app.buttons["ingredients-reset"].tapOrFail()
    }
}
