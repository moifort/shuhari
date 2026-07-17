import XCTest

/// Smoke test for the library sort menu. Runs against the `-gallery home` harness
/// (fixtures, no server or signed-in user): opening the sort menu and picking
/// « Type de plat » must keep the library rows on screen.
@MainActor
final class LibrarySortMenuTest: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-gallery", "home"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testSortMenuKeepsRowsVisible() throws {
        // A fixture row is present up front.
        let firstRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-")
        ).firstMatch
        try firstRow.waitOrFail(timeout: 6, "no recipe rows in the gallery library")

        // Open the sort menu and pick « Type de plat ».
        try app.buttons["library-sort-menu"].tapOrFail()
        try app.buttons["Type de plat"].tapOrFail()

        // The library still renders its rows after choosing a sort.
        let rowAfter = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-")
        ).firstMatch
        try rowAfter.waitOrFail(timeout: 4, "library rows vanished after sorting by dish category")
    }
}
