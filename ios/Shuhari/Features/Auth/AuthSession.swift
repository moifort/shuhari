import FirebaseAuth
import Observation

/// Single source of truth for the currently authenticated Firebase user.
/// Lives at app scope; views that need to react to sign-in/out observe `user`.
@MainActor
@Observable
final class AuthSession {
    private(set) var user: User?
    @ObservationIgnored
    nonisolated(unsafe) private var handle: AuthStateDidChangeListenerHandle?

    init() {
        user = Auth.auth().currentUser
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Erase the account for good. Three steps, in an order that cannot be swapped:
    /// Apple hands out a fresh authorization code, Firebase revokes the Apple token
    /// with it, and only then does the server wipe the data and delete the account —
    /// after which there is no user left to revoke anything for.
    ///
    /// Throws `AppleReauthentication.Failure.canceled` when the cook backs out of the
    /// Apple sheet; nothing has happened at that point.
    func deleteAccount() async throws {
        let code = try await AppleReauthentication().authorizationCode()
        try await Auth.auth().revokeToken(withAuthorizationCode: code)
        try await SettingsAPI.deleteAccount()
        try Auth.auth().signOut()
    }
}
