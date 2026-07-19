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

    /// The fiche opens on a server-derived version; its header badge carries a
    /// "Version N" accessibility label. Any version is cookable and there is no
    /// promotion — a freshly appended version simply becomes the one the fiche shows.
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
}
