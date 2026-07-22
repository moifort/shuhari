import XCTest

/// Ephemeral quantity scaling on the recipe sheet: stepping one ingredient's
/// quantity rescales the whole shopping list proportionally, and reset lands back
/// on the stored recipe. Runs offline against the debug gallery's fixture
/// (Bœuf bourguignon v3) — no server, deterministic quantities.
@MainActor
final class IngredientScalingTest: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-gallery", "recipe"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testSteppingOneIngredientRescalesTheWholeList() throws {
        let recipe = RecipeDetailPage(app: app)

        // The stored v3 quantities: beef 1,2 kg / lardons 200 g / red wine 75 cl / flour 30 g.
        let beef = try recipe.ingredientQuantity(0).waitOrFail()
        XCTAssertEqual(beef.label, "1,2 kg")

        // Three −10 g ticks on the beef: 1200 → 1170 g, factor 0,975.
        for _ in 0..<3 { try recipe.stepIngredient(0, down: true) }
        XCTAssertEqual(beef.label, "1,17 kg")

        // Every other line followed the factor, each on its own kitchen grain.
        XCTAssertEqual(recipe.ingredientQuantity(1).label, "195 g") // lardons 200 × 0,975
        XCTAssertEqual(recipe.ingredientQuantity(4).label, "73 cl") // red wine 75 cl, kept in cl
        XCTAssertEqual(recipe.ingredientQuantity(6).label, "29 g") // flour 30 g

        // Reset drops the factor: back to the stored recipe.
        try recipe.resetScaling()
        XCTAssertEqual(beef.label, "1,2 kg")
        XCTAssertEqual(recipe.ingredientQuantity(1).label, "200 g")
        XCTAssertFalse(app.buttons["ingredients-reset"].exists)
    }
}
