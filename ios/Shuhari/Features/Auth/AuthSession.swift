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
}
