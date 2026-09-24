import Foundation
import Sentry

func reportError(_ error: Error) -> String {
    // No-op when the SDK was never started (blank DSN), so this is always safe.
    if !isCancellation(error) {
        SentrySDK.capture(error: error)
    }
    return error.localizedDescription
}

/// The request was called off rather than refused: its task was cancelled — the cook
/// left the screen that asked — and URLSession says so with its own error rather than
/// a `CancellationError`. Nothing failed.
func isCancellation(_ error: Error) -> Bool {
    let nsError = error as NSError
    return error is CancellationError
        || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
}
