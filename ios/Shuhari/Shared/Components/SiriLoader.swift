import SwiftUI

/// The "listening" Siri orb: eleven layered gradient blobs (vector PDF assets in
/// `Assets.xcassets/Siri/`) rotating and hue-shifting over a 12 s loop, composited
/// with `.hardLight`. A faithful port of Amos Gyamfi's ListeningSiriAnimation
/// (GetStream/purposeful-ios-animations) — same assets, transforms and blend, so
/// it renders exactly like the reference. Driven by a continuous phase so the loop
/// begins at its midpoint on appear. Designed for a dark backdrop (the analysing
/// screen goes black behind it). Respects Reduce Motion by holding a single static
/// frame. Purely presentational.
struct SiriLoader: View {
    /// Layout footprint; the artwork (largest layer ≈ 640 pt) is scaled to fit it.
    var size: CGFloat = 260

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the loop starts at its midpoint on appear.
    @State private var start = Date()

    private let period: TimeInterval = 12
    private var scale: CGFloat { size / 640 }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            orb(phase: reduceMotion ? 0.5 : phase(at: context.date))
        }
        .blendMode(.hardLight)
        .scaleEffect(scale)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Cycle position in `0...1` (0 and 1 are the two end poses); starts at 0.5.
    private func phase(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(start)
        return (elapsed / period + 0.5).truncatingRemainder(dividingBy: 1)
    }

    /// Linear blend between the two end poses at the given cycle position.
    private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private func orb(phase t: Double) -> some View {
        ZStack {
            Image("shadow")
            Image("icon-bg")

            Image("pink-top")
                .rotationEffect(.degrees(mix(320, -360, t)))
                .hueRotation(.degrees(mix(-270, 60, t)))

            Image("pink-left")
                .rotationEffect(.degrees(mix(-360, 180, t)))
                .hueRotation(.degrees(mix(-220, 300, t)))

            Image("blue-middle")
                .rotationEffect(.degrees(mix(-360, 420, t)))
                .hueRotation(.degrees(mix(-150, 0, t)))
                .rotation3DEffect(.degrees(75), axis: (x: mix(1, 5, t), y: 0, z: 0))

            Image("blue-right")
                .rotationEffect(.degrees(mix(-360, 420, t)))
                .hueRotation(.degrees(mix(720, -50, t)))
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: mix(-5, 15, t)))

            Image("intersect")
                .rotationEffect(.degrees(mix(30, -420, t)))
                .hueRotation(.degrees(mix(0, 720, t)))
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: 1, z: 1), perspective: mix(5, -5, t))

            Image("green-right")
                .rotationEffect(.degrees(mix(-180, 480, t)))
                .hueRotation(.degrees(mix(300, -15, t)))
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: mix(-1, 1, t), z: 0), perspective: mix(-1, 1, t))

            Image("green-left")
                .rotationEffect(.degrees(mix(240, -480, t)))
                .hueRotation(.degrees(mix(180, 50, t)))
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: mix(-5, 15, t), z: 0))

            Image("bottom-pink")
                .rotationEffect(.degrees(mix(400, -360, t)))
                .hueRotation(.degrees(mix(0, 230, t)))
                .opacity(0.25)
                .blendMode(.multiply)
                .rotation3DEffect(.degrees(75), axis: (x: 5, y: mix(1, -45, t), z: 0))

            Image("highlight")
                .rotationEffect(.degrees(mix(360, 250, t)))
                .hueRotation(.degrees(mix(0, 230, t)))
        }
    }
}

#Preview("Siri loader") {
    ZStack {
        Color.black.ignoresSafeArea()
        SiriLoader()
    }
}
