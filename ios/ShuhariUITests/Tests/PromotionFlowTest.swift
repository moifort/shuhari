import XCTest

/// Promotion loop: a recipe carrying a pending version is executed, a high-scoring
/// trial qualifies it, and the promotion sheet turns it into the current reference.
///
/// Relies on the server test harness exposing `POST /test/seed-recipe` with a
/// pending version; adjust `TestAPIClient.seedRecipeWithPendingVersion` to match.
final class PromotionFlowTest: BaseUITest {

    func testPromotePendingVersion() async throws {
        let title = "Espresso Promotion"
        try api.seedRecipeWithPendingVersion(title: title)

        let tabBar = TabBarPage(app: app)
        // "Espresso Promotion" is a coffee recipe → the Café tab.
        let home = try tabBar.goToCategory("Café").verify()
        try home.verifyRecipeVisible(title)

        let recipe = try home.openRecipe(title)
        try recipe.verify()
        try recipe.verifyPendingVersion(2)

        // Execute the pending version and record a high-scoring trial.
        let execute = try recipe.executePending(2).verify()
        let capture = try execute.done().verify()
        _ = try capture.pickNote(9)
        _ = try capture.typeRemarks("Équilibré, chocolat noir en finale. Très proche du but.")
        try capture.save()

        // The promotion sheet appears — promote.
        try app.buttons["promote-button"].tapOrFail(timeout: 15)

        // Back on the fiche the pending banner is gone (v2 is now current).
        try recipe.verify()
        XCTAssertFalse(app.buttons["execute-v2-button"].waitForExistence(timeout: 3), "pending v2 banner should disappear after promotion")
    }
}
