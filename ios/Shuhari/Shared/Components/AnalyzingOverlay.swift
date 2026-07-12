import SwiftUI

/// A floating Liquid Glass HUD shown while the AI works (import analysis,
/// proposal generation). The dimming scrim blocks all interaction with the
/// content underneath. Raw `glassEffect` is reserved for this card and the
/// camera-overlay controls (which need the `.clear` variant over live video) —
/// everything else gets glass from the standard button styles.
struct AnalyzingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue.opacity(0.3), .orange.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        AnalyzingOverlay(message: "L’IA analyse tes remarques…")
    }
}
