import SwiftUI

/// The analysing stage of an AI wait: the listening Siri orb (`SiriLoader`) over a
/// full-bleed scrim with its message. The scrim is a native material, so the stage
/// follows the system appearance instead of forcing the screen to black — the orb
/// carries its own dark stage. Purely presentational.
struct AIThinkingCard: View {
    let message: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: Theme.Spacing.xl) {
                SiriLoader()
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Clair") {
    AIThinkingCard(message: "Analyse IA…")
        .preferredColorScheme(.light)
}

#Preview("Sombre") {
    AIThinkingCard(message: "Analyse IA…")
        .preferredColorScheme(.dark)
}
