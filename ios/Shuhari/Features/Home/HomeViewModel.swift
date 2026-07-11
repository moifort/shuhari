import Foundation

@MainActor @Observable
final class HomeViewModel {
    var data: HomeData?
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            data = try await HomeAPI.getHome()
        } catch {
            self.error = reportError(error)
        }
        isLoading = false
    }
}
