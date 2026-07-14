import SwiftUI

/// The "listening" Siri orb: eleven layered gradient blobs (vector PDF assets in
/// `Assets.xcassets/Siri/`) rotating and hue-shifting over a 12 s loop, composited
/// with `.hardLight`. A faithful port of Amos Gyamfi's ListeningSiriAnimation
/// (GetStream/purposeful-ios-animations) — same assets, transforms and blend, so
/// it renders exactly like the reference. Designed for a dark backdrop (the
/// analysing screen goes black behind it). Respects Reduce Motion by holding a
/// single static frame. Purely presentational.
struct SiriLoader: View {
    /// Layout footprint; the artwork (largest layer ≈ 640 pt) is scaled to fit it.
    var size: CGFloat = 260

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    private var scale: CGFloat { size / 640 }

    var body: some View {
        ZStack {
            Image("shadow")
            Image("icon-bg")

            Image("pink-top")
                .rotationEffect(.degrees(animate ? 320 : -360))
                .hueRotation(.degrees(animate ? -270 : 60))

            Image("pink-left")
                .rotationEffect(.degrees(animate ? -360 : 180))
                .hueRotation(.degrees(animate ? -220 : 300))

            Image("blue-middle")
                .rotationEffect(.degrees(animate ? -360 : 420))
                .hueRotation(.degrees(animate ? -150 : 0))
                .rotation3DEffect(.degrees(75), axis: (x: animate ? 1 : 5, y: 0, z: 0))

            Image("blue-right")
                .rotationEffect(.degrees(animate ? -360 : 420))
                .hueRotation(.degrees(animate ? 720 : -50))
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: animate ? -5 : 15))

            Image("intersect")
                .rotationEffect(.degrees(animate ? 30 : -420))
                .hueRotation(.degrees(animate ? 0 : 720))
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: 1, z: 1), perspective: animate ? 5 : -5)

            Image("green-right")
                .rotationEffect(.degrees(animate ? -300 : 360))
                .hueRotation(.degrees(animate ? 300 : -15))
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: animate ? -1 : 1, z: 0), perspective: animate ? -1 : 1)

            Image("green-left")
                .rotationEffect(.degrees(animate ? 360 : -360))
                .hueRotation(.degrees(animate ? 180 : 50))
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: animate ? -5 : 15, z: 0))

            Image("bottom-pink")
                .rotationEffect(.degrees(animate ? 400 : -360))
                .hueRotation(.degrees(animate ? 0 : 230))
                .opacity(0.25)
                .blendMode(.multiply)
                .rotation3DEffect(.degrees(75), axis: (x: 5, y: animate ? 1 : -45, z: 0))

            Image("highlight")
                .rotationEffect(.degrees(animate ? 360 : 250))
                .hueRotation(.degrees(animate ? 0 : 230))
        }
        .blendMode(.hardLight)
        .scaleEffect(scale)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            // Spin the orb continuously at a constant size.
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

#Preview("Siri loader") {
    ZStack {
        Color.black.ignoresSafeArea()
        SiriLoader()
    }
}
