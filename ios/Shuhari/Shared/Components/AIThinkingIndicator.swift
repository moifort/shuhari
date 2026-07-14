import SwiftUI

/// A Liquid Glass "AI is thinking" indicator: a variable-colour `wand.and.sparkles`
/// symbol over a bright, flowing Siri-style glow. Several blurred colour blobs
/// orbit the centre at different speeds and directions, brightening where they
/// overlap (`.plusLighter`) with a slow hue drift — the Apple-Intelligence idiom
/// (inspired by Amos Gyamfi's layered listening animation, rebuilt asset-free with
/// plain shapes). Shown while the import AI analyses a photo, link or text.
/// Respects Reduce Motion (static blobs, no orbit/hue drift, non-repeating symbol
/// effect). Purely presentational.
struct AIThinkingIndicator: View {
    var size: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    /// One orbiting glow blob: a colour offset from centre, spun around it.
    private struct Blob {
        let color: Color
        let scale: CGFloat      // diameter, relative to `size`
        let offset: CGFloat     // orbit radius, relative to `size`
        let duration: Double    // seconds per full turn
        let clockwise: Bool
    }

    private var blobs: [Blob] {
        [
            Blob(color: Theme.Status.changed, scale: 1.05, offset: 0.34, duration: 9, clockwise: true),
            Blob(color: .purple, scale: 0.95, offset: 0.40, duration: 12, clockwise: false),
            Blob(color: .pink, scale: 0.80, offset: 0.30, duration: 7, clockwise: true),
            Blob(color: Theme.Status.tmx, scale: 0.90, offset: 0.44, duration: 14, clockwise: false),
            Blob(color: .indigo, scale: 0.85, offset: 0.26, duration: 10, clockwise: true),
        ]
    }

    var body: some View {
        ZStack {
            glow

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
            spin = true
        }
    }

    private var glow: some View {
        ZStack {
            ForEach(Array(blobs.enumerated()), id: \.offset) { index, blob in
                Circle()
                    .fill(blob.color)
                    .frame(width: size * blob.scale, height: size * blob.scale)
                    .offset(y: -size * blob.offset)
                    // Spread blobs evenly (balanced even when Reduce Motion pins
                    // the spin), then orbit from that base angle.
                    .rotationEffect(.degrees(Double(index) / Double(blobs.count) * 360) + orbit(blob))
                    .blendMode(.plusLighter)   // brighten where blobs overlap…
                    .animation(orbitAnimation(blob), value: spin)
            }
        }
        // …but keep that additive blend inside the group so the halo composites
        // normally over the background — stays vivid in light and dark alike.
        .compositingGroup()
        .blur(radius: size * 0.34)
        .opacity(0.9)
        .hueRotation(.degrees(reduceMotion ? 0 : (spin ? 40 : -40)))
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true),
            value: spin
        )
    }

    private func orbit(_ blob: Blob) -> Angle {
        guard !reduceMotion, spin else { return .zero }
        return .degrees(blob.clockwise ? 360 : -360)
    }

    private func orbitAnimation(_ blob: Blob) -> Animation? {
        guard !reduceMotion else { return nil }
        return .linear(duration: blob.duration).repeatForever(autoreverses: false)
    }
}

/// The titled "AI is thinking" glow — the analysing phase of the import review
/// sheet presents this directly over an opaque background (no card chrome): just
/// the halo and its message, so the glow is the whole stage.
struct AIThinkingCard: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            AIThinkingIndicator()
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Card") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        AIThinkingCard(message: "Analyse IA…")
    }
}

#Preview("Indicator") {
    AIThinkingIndicator(size: 140)
}
