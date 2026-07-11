import Foundation

/// Resolves the Firebase Functions endpoint that hosts the GraphQL API.
/// All HTTP transport happens through GraphQLClient (Apollo iOS).
///
/// The default URL is filled in after `bun run bootstrap` deploys the Cloud
/// Function (the bootstrap output prints it). Override it at runtime via the
/// `serverURL` UserDefault (debug settings) or the `-serverURLDev` launch
/// argument (UI tests point it at the local emulator).
struct APIClient: Sendable {
    static let shared = APIClient()

    private static let serverURLKey = "serverURL"
    private static let defaultServerURL = "https://shuhari-server-bkr37damua-ey.a.run.app"

    var baseURL: URL {
        if let dev = UserDefaults.standard.string(forKey: "serverURLDev"), !dev.isEmpty {
            return URL(string: dev) ?? URL(string: Self.defaultServerURL)!
        }
        let stored = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? Self.defaultServerURL
        return URL(string: stored) ?? URL(string: Self.defaultServerURL)!
    }
}
