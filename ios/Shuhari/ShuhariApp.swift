import FirebaseCore
import SwiftUI

@main
struct ShuhariApp: App {
    init() {
        FirebaseApp.configure()
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
