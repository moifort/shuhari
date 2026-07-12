import Foundation
import SwiftUI

/// The single home read-model store, shared by the three category tabs through
/// the environment: one `getHome()` load feeds every tab (each filters to its
/// own types), so recording a trial in one tab never leaves another stale.
@MainActor @Observable
final class HomeStore {
    var data: HomeData?
    var isLoading = false
    var error: String?

    @ObservationIgnored private var inFlight: Task<Void, Never>?

    /// Single-flight: the three tabs all request a load at startup — they must
    /// share one network call, not race three.
    func load() async {
        if let inFlight {
            return await inFlight.value
        }
        let task = Task {
            isLoading = true
            error = nil
            do {
                data = try await HomeAPI.getHome()
            } catch {
                self.error = reportError(error)
            }
            isLoading = false
        }
        inFlight = task
        await task.value
        inFlight = nil
    }
}
