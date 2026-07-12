import XCTest

@MainActor
struct TabBarPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.tabBars.firstMatch.waitOrFail()
        return self
    }

    @discardableResult
    func goToCarnet() throws -> HomePage {
        try app.tabBars.buttons["Carnet"].tapOrFail()
        return HomePage(app: app)
    }

    @discardableResult
    func goToImport() throws -> ImportPage {
        try app.tabBars.buttons["Importer"].tapOrFail()
        return ImportPage(app: app)
    }
}
