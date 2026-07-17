import Foundation

struct TestRecipe: Decodable {
    let id: String
    let title: String
    let type: String
}

struct TestAPIResponse<T: Decodable>: Decodable {
    let status: Int
    let data: T
}

/// Thin REST client against the local test server's helper endpoints (reset +
/// seeding). Mirrors Vinarium's TestAPIClient; the exact seed routes depend on
/// the server test harness.
final class TestAPIClient: @unchecked Sendable {
    static let shared = TestAPIClient()

    private let baseURL: URL
    private let token = TestSecrets.apiToken
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    init() {
        let envURL = ProcessInfo.processInfo.environment["TEST_SERVER_URL"]
        self.baseURL = URL(string: envURL ?? "http://localhost:3000")!
    }

    // MARK: - Test reset

    func resetDatabase() throws {
        _ = try performRequest("POST", path: "/test/reset")
    }

    // MARK: - Seeding

    /// Seed a recipe with a pending (toTest) version so the trial-loop and
    /// promotion tests have something to execute. Returns the created recipe.
    @discardableResult
    func seedRecipeWithPendingVersion(title: String, type: String = "plat") throws -> TestRecipe {
        let data = try performRequest("POST", path: "/test/seed-recipe", jsonBody: [
            "title": title,
            "type": type,
            "withPendingVersion": true,
        ])
        return try decoder.decode(TestAPIResponse<TestRecipe>.self, from: data).data
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
