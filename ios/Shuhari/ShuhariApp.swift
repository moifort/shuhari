import FirebaseCore
import Sentry
import SwiftUI

// A Sentry DSN is public by design (safe to commit). Paste the real project DSN
// here; a blank/placeholder value leaves error reporting disabled, mirroring the
// backend plugin (server/plugins/01-sentry.ts).
private let sentryDSN = "https://642233dedd9035883fcaf79462c61c09@o4510952263909376.ingest.de.sentry.io/4511769044123728"

@main
struct ShuhariApp: App {
    init() {
        FirebaseApp.configure()
        startErrorReporting()
    }

    /// Release builds only. A crash from the simulator, the debug gallery or a UI
    /// test is not an incident; letting it into the same stream as real ones buries
    /// the reports that matter under noise nobody will triage. This mirrors the
    /// backend, where the DSN only exists in production's Secret Manager and is
    /// simply absent everywhere else.
    private func startErrorReporting() {
        #if !DEBUG
        guard sentryDSN.hasPrefix("https://") else { return }
        SentrySDK.start { options in
            options.dsn = sentryDSN
            options.environment = "production"
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = UserDefaults.standard.string(forKey: "gallery") {
                DebugGallery(screen: screen)
            } else {
                AuthRoot()
            }
            #else
            AuthRoot()
            #endif
        }
    }
}
