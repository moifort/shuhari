import FirebaseCore
import Sentry
import SwiftUI

// A Sentry DSN is public by design (safe to commit). Paste the real project DSN
// here; a blank/placeholder value leaves error reporting disabled, mirroring the
// backend plugin (server/plugins/01-sentry.ts).
private let sentryDSN = ""

@main
struct ShuhariApp: App {
    init() {
        FirebaseApp.configure()
        if sentryDSN.hasPrefix("https://") {
            SentrySDK.start { options in
                options.dsn = sentryDSN
            }
        }
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
