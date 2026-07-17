import XCTest

/// Promotion loop: a recipe carrying a pending version is executed, a high-scoring
/// trial qualifies it, and the promotion sheet turns it into the current reference.
///
/// Relies on the server test harness exposing `POST /test/seed-recipe` with a
/// pending version; adjust `TestAPIClient.seedRecipeWithPendingVersion` to match.
final class PromotionFlowTest: BaseUITest {

    func testPromotePendingVersion() async throws {
        let title = "Risotto Promotion"
        try api.seedRecipeWithPendingVersion(title: title, type: "plat", category: "plat")

        let tabBar = TabBarPage(app: app)
        // The cuisine-only app has a single content tab: the Carnet.
        let home = try tabBar.goToCarnet().verify()
        try home.verifyRecipeVisible(title)

        let recipe = try home.openRecipe(title)
        try recipe.verify()
        try recipe.verifyPendingVersion(2)

        // Open the pending version and record a high-scoring trial.
        let capture = try recipe.openToTest(2).verify()
        _ = try capture.pickStars(5) // 5/5 ≥ 4 → promotion
        _ = try capture.typeRemarks("Équilibré, chocolat noir en finale. Très proche du but.")
        try capture.save()

        // The promotion sheet appears — promote.
        try app.buttons["promote-button"].tapOrFail(timeout: 15)

        // Back on the fiche the pending CTA is gone (v2 is now current).
        try recipe.verify()
        XCTAssertFalse(app.buttons["to-test-button"].waitForExistence(timeout: 3), "pending v2 CTA should disappear after promotion")
    }
}
