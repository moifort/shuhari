import SwiftUI

/// The login logo: a flask filling up with orange liquid. Two stacked SF Symbols —
/// `flask.fill` (the liquid) masked by a rising wave, under `flask` (the glass) so
/// the contour stays crisp above the water line. On appear the level eases up to
/// the bulb over ~1.8 s, then the surface keeps a light permanent slosh. Respects
/// Reduce Motion by holding the filled state with a flat surface. Purely
/// presentational.
struct LiquidFlask: View {
    var size: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// Seconds for the level to rise from empty to `finalLevel`.
    private let fillDuration: TimeInterval = 1.8
    /// Resting level as a fraction of the glyph height — a flask fills at the
    /// bulb, never up the neck.
    private let finalLevel: CGFloat = 0.55
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
                    .foregroundStyle(Color.accentColor)
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
