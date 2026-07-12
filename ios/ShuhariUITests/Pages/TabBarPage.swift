import XCTest

@MainActor
struct TabBarPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.tabBars.firstMatch.waitOrFail()
        return self
    }

    /// Tap one of the category tabs (Cuisine / Café / Cocktail) by its label.
    @discardableResult
    func goToCategory(_ name: String) throws -> HomePage {
        try app.tabBars.buttons[name].tapOrFail()
        return HomePage(app: app, title: name)
    }

    @discardableResult
    func goToImport() throws -> ImportPage {
        try app.tabBars.buttons["Importer"].tapOrFail()
        return ImportPage(app: app)
    }
}
