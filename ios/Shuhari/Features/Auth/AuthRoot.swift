import SwiftUI

/// Top-level gate: shows LoginView when no Firebase user is signed in,
/// otherwise the main TabView (`ContentView`).
struct AuthRoot: View {
    @State private var session = AuthSession()

    var body: some View {
        Group {
            if session.user == nil {
                LoginView()
            } else {
                ContentView()
            }
        }
        .environment(session)
    }
}
