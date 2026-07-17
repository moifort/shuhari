import XCTest

@MainActor
struct TabBarPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.tabBars.firstMatch.waitOrFail()
        return self
    }

    /// Tap the single content tab — the "Carnet" (all cuisine recipes: plats & Thermomix).
    @discardableResult
    func goToCarnet() throws -> HomePage {
        try app.tabBars.buttons["Carnet"].tapOrFail()
        return HomePage(app: app, title: "Carnet")
    }

    @discardableResult
    func goToImport() throws -> ImportPage {
        try app.tabBars.buttons["Importer"].tapOrFail()
        return ImportPage(app: app)
    }
}
