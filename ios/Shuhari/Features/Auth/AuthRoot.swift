import SwiftUI

/// Top-level gate: shows LoginView when no Firebase user is signed in,
/// otherwise the main TabView (`ContentView`).
struct AuthRoot: View {
    @State private var session = AuthSession()
    /// Owned here rather than per-screen: it listens to `Transaction.updates` for
    /// the whole life of the app, and a renewal must land wherever the cook is.
    @State private var subscription = SubscriptionStore()

    var body: some View {
        Group {
            if session.user == nil {
                LoginView()
            } else {
                ContentView()
                    // Signing in is what makes the entitlement readable: the
                    // server answers for the authenticated cook.
                    .task(id: session.user?.uid) { await subscription.refresh() }
            }
        }
        .environment(session)
        .environment(subscription)
    }
}
