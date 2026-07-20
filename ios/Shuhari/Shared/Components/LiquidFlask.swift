import SwiftUI

/// The login logo: an orange flask filling up with liquid, then bubbling like a
/// chemical reaction. Two stacked SF Symbols — `flask.fill` (the liquid) masked by
/// a rising wave, under an orange `flask` (the glass) — plus a loop of small orange
/// bubbles escaping from the top of the flask once the fill settles. On appear the
/// level eases up to the bulb over ~1.8 s, then the surface keeps a light permanent
/// slosh. Respects Reduce Motion by holding the filled state with a flat surface
/// and no bubbles. Purely presentational.
struct LiquidFlask: View {
    var size: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// Seconds for the level to rise from empty to `finalLevel`.
    private let fillDuration: TimeInterval = 1.8
    /// Resting level as a fraction of the glyph height — low in the bulb, so the
    /// sloshing surface stays visible under the neck.
    private let finalLevel: CGFloat = 0.42
    /// Seconds for one full slosh oscillation of the surface.
    private let sloshPeriod: TimeInterval = 1.6

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            ZStack {
                Image(systemName: "flask.fill")
                    .font(.system(size: size))
                    .foregroundStyle(Color.orange)
                    .mask {
                        WaveShape(
                            level: reduceMotion ? finalLevel : level(at: elapsed),
                            amplitude: reduceMotion ? 0 : size * 0.025,
                            phase: 2 * .pi * elapsed / sloshPeriod
                        )
                    }
                Image(systemName: "flask")
                    .font(.system(size: size))
                    .foregroundStyle(Color.orange)
                if !reduceMotion {
                    ForEach(bubbles.indices, id: \.self) { index in
                        bubble(bubbles[index], at: elapsed)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Fill level at `elapsed` seconds: a cubic ease-out from 0 to `finalLevel`,
    /// then steady — the slosh alone keeps the surface alive.
    private func level(at elapsed: TimeInterval) -> CGFloat {
        let t = min(max(elapsed / fillDuration, 0), 1)
        let easedOut = 1 - pow(1 - t, 3)
        return finalLevel * easedOut
    }

    /// One bubble of the escaping loop: drifts around `xOffset`, reborn every
    /// `period` seconds, `delay` staggering it from the others. Fractions are of
    /// `size` so the swarm scales with the glyph.
    private struct Bubble {
        let xOffset: CGFloat
        let diameter: CGFloat
        let period: TimeInterval
        let delay: TimeInterval
    }

    private let bubbles: [Bubble] = [
        Bubble(xOffset: -0.08, diameter: 0.16, period: 2.6, delay: 0),
        Bubble(xOffset: 0.06, diameter: 0.11, period: 2.1, delay: 0.7),
        Bubble(xOffset: 0, diameter: 0.13, period: 2.9, delay: 1.3),
        Bubble(xOffset: 0.12, diameter: 0.09, period: 2.3, delay: 1.8),
    ]

    /// A bubble pops out of the flask mouth and climbs above it — fading in as it
    /// escapes, out as it bursts. The swarm only starts once the flask has filled.
    private func bubble(_ bubble: Bubble, at elapsed: TimeInterval) -> some View {
        let alive = max(elapsed - fillDuration - bubble.delay, 0)
        let progress = alive > 0 ? (alive / bubble.period).truncatingRemainder(dividingBy: 1) : 0
        let rise = size * (-0.38 - 0.75 * progress)
        let wobble = size * 0.02 * sin(progress * 4 * .pi + bubble.delay)
        let opacity = alive > 0 ? min(progress / 0.15, (1 - progress) / 0.25, 1) : 0
        return Circle()
            .fill(Color.orange)
            .frame(width: size * bubble.diameter, height: size * bubble.diameter)
            .offset(x: size * bubble.xOffset + wobble, y: rise)
            .opacity(opacity * 0.9)
    }
}

/// The liquid mask: a rectangle anchored to the bottom whose top edge is a
/// travelling sine. `level` is the filled fraction of the rect height (0 = empty,
/// 1 = full), `amplitude` the wave half-height in points, `phase` its travel.
private struct WaveShape: Shape {
    var level: CGFloat
    var amplitude: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard level > 0 else { return path }
        let surfaceY = rect.maxY - level * rect.height
        let wavelength = rect.width / 1.5
        func waveY(_ x: CGFloat) -> CGFloat {
            surfaceY + amplitude * sin(2 * .pi * x / wavelength + phase)
        }
        path.move(to: CGPoint(x: rect.minX, y: waveY(rect.minX)))
        for x in stride(from: rect.minX + 1, through: rect.maxX, by: 1) {
            path.addLine(to: CGPoint(x: x, y: waveY(x)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Liquid flask") {
    LiquidFlask(size: 96)
}
