import SwiftUI

/// An SF Symbol that becomes a spinner while its action is in flight. Every CTA
/// firing a network call wears one, so the wait is never silent.
struct ActionIcon: View {
    let systemImage: String
    let isRunning: Bool

    var body: some View {
        if isRunning {
            ProgressView()
        } else {
            Image(systemName: systemImage)
        }
    }
}

#Preview("Repos") {
    ActionIcon(systemImage: "checkmark", isRunning: false)
}

#Preview("En cours") {
    ActionIcon(systemImage: "checkmark", isRunning: true)
}
