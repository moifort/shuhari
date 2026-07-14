import SwiftUI

/// The analysing stage of the import review sheet: the listening Siri orb
/// (`SiriLoader`) over a full-bleed black backdrop with its message. The dark
/// stage is deliberate — the orb's `.hardLight` compositing only reads correctly
/// on black, matching the reference animation. Purely presentational.
struct AIThinkingCard: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.xl) {
                SiriLoader()
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

#Preview("Card") {
    AIThinkingCard(message: "Analyse IA…")
}
