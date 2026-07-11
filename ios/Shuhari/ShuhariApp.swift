import FirebaseCore
import SwiftUI

@main
struct ShuhariApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            AuthRoot()
        }
    }
}
