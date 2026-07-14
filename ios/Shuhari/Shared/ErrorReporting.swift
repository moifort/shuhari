import Foundation
import Sentry

func reportError(_ error: Error) -> String {
    // No-op when the SDK was never started (blank DSN), so this is always safe.
    SentrySDK.capture(error: error)
    return error.localizedDescription
}
