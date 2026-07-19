import Foundation

/// Thin REST client against the local test server's helper endpoints (DB reset).
/// The derived recipe model has no promotion/toTest seeding: the attempt-loop test
/// builds its own state through the app's import + attempt flow, so the client only
/// needs to reset the database between tests.
final class TestAPIClient: @unchecked Sendable {
    static let shared = TestAPIClient()

    private let baseURL: URL
    private let token = TestSecrets.apiToken
    private let session = URLSession.shared

    init() {
        let envURL = ProcessInfo.processInfo.environment["TEST_SERVER_URL"]
        self.baseURL = URL(string: envURL ?? "http://localhost:3000")!
    }

    // MARK: - Test reset

    func resetDatabase() throws {
        _ = try performRequest("POST", path: "/test/reset")
    }

    // MARK: - HTTP

    @discardableResult
    private func performRequest(_ method: String, path: String, jsonBody: [String: Any]? = nil) throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }

        var responseData: Data?
        var responseError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { data, response, error in
            if let error {
                responseError = error
            } else if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                responseError = NSError(domain: "TestAPI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(http.statusCode) for \(method) \(path)",
                ])
            } else {
                responseData = data
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let error = responseError { throw error }
        return responseData ?? Data()
    }
}
