import XCTest

struct UITestFailure: Error {
    let message: String
}

extension XCUIElement {
    @discardableResult
    func waitOrFail(timeout: TimeInterval = 6, _ message: String? = nil, file: StaticString = #file, line: UInt = #line) throws -> XCUIElement {
        guard self.waitForExistence(timeout: timeout) else {
            let msg = message ?? "Element \(self) not found"
            XCTFail(msg, file: file, line: line)
            throw UITestFailure(message: msg)
        }
        return self
    }

    func tapOrFail(timeout: TimeInterval = 6, file: StaticString = #file, line: UInt = #line) throws {
        try waitOrFail(timeout: timeout, file: file, line: line)
        self.tap()
    }
}

@MainActor
class BaseUITest: XCTestCase {
    var app: XCUIApplication!
    var api: TestAPIClient!

    override func setUp() async throws {
        continueAfterFailure = false
        api = TestAPIClient.shared
        try? api.resetDatabase()
        app = XCUIApplication()
        app.launchArguments = ["-serverURLDev", "http://localhost:3000", "-serverMode", "dev", "-UITestPhoto"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
        try? api.resetDatabase()
    }
}
