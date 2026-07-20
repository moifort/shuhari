import SwiftUI

/// The animated flask, looping like a slow chemical experiment: the liquid rises,
/// rests a beat, then boils away — each escaping bubble carrying the level down —
/// and the cycle starts over. Two stacked SF Symbols — `flask.fill` (the liquid)
/// masked by a rising wave, under a `flask` of the same tint (the glass) — plus the swarm
/// of bubbles popping out of the neck during the evaporation phase. The glass
/// itself swirls like a flask stirred by the neck, harder the fuller it is. Used as the
/// login logo and as the library's first-load indicator (cold functions make that
/// wait long enough to deserve a show). Respects Reduce Motion by holding the
/// filled state with a flat surface and no bubbles. Purely presentational.
struct LiquidFlask: View {
    var size: CGFloat = 64
    /// Colour of the glass, the liquid and the bubbles — orange logo by default,
    /// `.primary` when the flask plays the loading indicator.
    var tint: Color = .orange

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// Seconds for the level to rise from empty to `finalLevel`.
    private let fillDuration: TimeInterval = 1.8
    /// Seconds the flask rests full — long enough for the fill to read before it boils.
    private let holdDuration: TimeInterval = 0.6
    /// Seconds for the level to evaporate back to empty, bubbles escaping meanwhile.
    private let evaporateDuration: TimeInterval = 3.2
    /// Resting level as a fraction of the glyph height — low in the bulb, so the
    /// sloshing surface stays visible under the neck.
    private let finalLevel: CGFloat = 0.42
    /// Seconds for one full slosh oscillation of the surface.
    private let sloshPeriod: TimeInterval = 1.6
    /// Seconds for one full swirl of the glass — the wrist gesture that stirs the
    /// liquid, the flask held by the neck while its base sweeps a circle.
    private let swirlPeriod: TimeInterval = 1.1

    private var cycleDuration: TimeInterval { fillDuration + holdDuration + evaporateDuration }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let cycleTime = elapsed.truncatingRemainder(dividingBy: cycleDuration)
            ZStack {
                ZStack {
                    Image(systemName: "flask.fill")
                        .font(.system(size: size))
                        .foregroundStyle(tint)
                        .mask {
                            WaveShape(
                                level: reduceMotion ? finalLevel : level(at: cycleTime),
                                amplitude: reduceMotion ? 0 : size * 0.025,
                                phase: 2 * .pi * elapsed / sloshPeriod
                            )
                        }
                    Image(systemName: "flask")
                        .font(.system(size: size))
                        .foregroundStyle(tint)
                }
                .modifier(swirl(elapsed: elapsed, cycleTime: cycleTime))
                if !reduceMotion {
                    ForEach(bubbles.indices, id: \.self) { index in
                        bubble(bubbles[index], at: cycleTime)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The glass motion: the mixing swirl — held by the neck (rotation anchored at
    /// the top), the base sweeps a circle, the tilt and the sideways drift a
    /// quarter turn apart. Its intensity follows the liquid level: a full flask
    /// gets the vigorous stir, an empty one barely moves.
    private func swirl(elapsed: TimeInterval, cycleTime: TimeInterval) -> SwirlEffect {
        if reduceMotion { return SwirlEffect(tilt: .zero, offset: .zero) }
        let beat = 2 * .pi * elapsed / swirlPeriod
        let intensity = 0.35 + 0.65 * level(at: cycleTime) / finalLevel
        return SwirlEffect(
            tilt: .degrees(5 * intensity * sin(beat)),
            offset: CGSize(
                width: size * 0.04 * intensity * cos(beat),
                height: size * 0.012 * intensity * sin(2 * beat)
            )
        )
    }

    /// The swirl applied: tilt around the neck, then the drift of the whole glass.
    private struct SwirlEffect: ViewModifier {
        let tilt: Angle
        let offset: CGSize

        func body(content: Content) -> some View {
            content
                .rotationEffect(tilt, anchor: .top)
                .offset(offset)
        }
    }

    /// Fill level at `cycleTime` seconds into the loop: a cubic ease-out up to
    /// `finalLevel`, a full-flask rest, then a smooth ease back to empty as the
    /// bubbles boil the liquid off.
    private func level(at cycleTime: TimeInterval) -> CGFloat {
        if cycleTime < fillDuration {
            let t = cycleTime / fillDuration
            return finalLevel * (1 - pow(1 - t, 3))
        }
        if cycleTime < fillDuration + holdDuration {
            return finalLevel
        }
        let t = (cycleTime - fillDuration - holdDuration) / evaporateDuration
        let easedInOut = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        return finalLevel * (1 - easedInOut)
    }

    /// One bubble of the evaporation: takes off `delay` seconds into the phase and
    /// climbs for `rise` seconds, once per cycle. `delay + rise` must fit within
    /// `evaporateDuration` so no bubble outlives the boil. Fractions are of `size`
    /// so the swarm scales with the glyph.
    private struct Bubble {
        let xOffset: CGFloat
        let diameter: CGFloat
        let rise: TimeInterval
        let delay: TimeInterval
    }

    private let bubbles: [Bubble] = [
        Bubble(xOffset: -0.08, diameter: 0.16, rise: 1.8, delay: 0),
        Bubble(xOffset: 0.06, diameter: 0.11, rise: 1.6, delay: 0.4),
        Bubble(xOffset: 0.12, diameter: 0.09, rise: 1.7, delay: 0.8),
        Bubble(xOffset: 0, diameter: 0.13, rise: 1.9, delay: 1.1),
        Bubble(xOffset: -0.05, diameter: 0.1, rise: 1.6, delay: 1.5),
    ]

    /// A bubble pops out of the flask mouth and climbs above it — fading in as it
    /// escapes, out as it bursts. Bubbles only fly during the evaporation phase,
    /// each exactly once per cycle.
    private func bubble(_ bubble: Bubble, at cycleTime: TimeInterval) -> some View {
        let alive = cycleTime - fillDuration - holdDuration - bubble.delay
        let flying = alive > 0 && alive < bubble.rise
        let progress = flying ? alive / bubble.rise : 0
        let rise = size * (-0.38 - 0.75 * progress)
        let wobble = size * 0.02 * sin(progress * 4 * .pi + bubble.delay)
        let opacity = flying ? min(progress / 0.15, (1 - progress) / 0.25, 1) : 0
        return Circle()
            .fill(tint)
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
