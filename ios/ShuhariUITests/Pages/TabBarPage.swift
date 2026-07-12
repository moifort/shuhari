import XCTest

/// Entry-point coordinator for the single-screen Carnet root. Import is no longer
/// a tab — it opens as a modal sheet from the "+" button in the Carnet toolbar.
@MainActor
struct TabBarPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Carnet"].waitOrFail()
        return self
    }

    @discardableResult
    func goToCarnet() throws -> HomePage {
        try app.navigationBars["Carnet"].waitOrFail()
        return HomePage(app: app)
    }

    @discardableResult
    func goToImport() throws -> ImportPage {
        try app.buttons["import-button"].tapOrFail()
        return ImportPage(app: app)
    }
}
