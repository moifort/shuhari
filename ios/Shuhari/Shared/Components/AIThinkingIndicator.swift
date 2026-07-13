import SwiftUI

/// A Liquid Glass "AI is thinking" indicator: a variable-colour `wand.and.sparkles`
/// symbol haloed by a soft, slowly pulsing angular-gradient glow — the "Siri is
/// reasoning" idiom. Shown while the import AI analyses a photo, link or text.
/// Respects Reduce Motion (static halo, no pulse/rotation, non-repeating symbol
/// effect). Purely presentational.
struct AIThinkingIndicator: View {
    var size: CGFloat = 76

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            AngularGradient(
                colors: [Theme.Status.changed, .purple, Theme.Status.tmx, Theme.Status.changed],
                center: .center
            )
            .blur(radius: size * 0.5)
            .frame(width: size * 1.9, height: size * 1.9)
            .scaleEffect(reduceMotion ? 1 : (animate ? 1.08 : 0.86))
            .opacity(reduceMotion ? 0.55 : (animate ? 0.8 : 0.4))
            .rotationEffect(.degrees(reduceMotion ? 0 : (animate ? 32 : -32)))

            Image(systemName: "wand.and.sparkles")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Status.changed, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(
                    .variableColor.iterative.reversing,
                    options: reduceMotion ? .nonRepeating : .repeating
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// The titled glass card wrapping `AIThinkingIndicator` — the analysing phase of
/// the import review sheet presents this over an opaque background.
struct AIThinkingCard: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            AIThinkingIndicator()
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.xl + Theme.Spacing.s)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.overlay))
    }
}

#Preview("Card") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        AIThinkingCard(message: "Analyse IA…")
    }
}

#Preview("Indicator") {
    AIThinkingIndicator(size: 120)
}
