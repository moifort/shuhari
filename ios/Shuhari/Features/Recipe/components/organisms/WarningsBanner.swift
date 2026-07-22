import SwiftUI

/// The recipe sheet's opening section: the cook's recipe-level cautions, read
/// before anything else ("Le fouet doit être mis dès le début"). One row per
/// caution on the attempt accent, so a critical gesture cannot be missed when
/// the recipe opens. Renders nothing when the recipe carries none (never an
/// empty section). Composes as a `Section` directly inside a `List`.
struct WarningsBanner: View {
    let warnings: [String]

    var body: some View {
        if !warnings.isEmpty {
            Section {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Status.attempt)
                        Text(warning)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(Theme.Status.attempt.opacity(0.12))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Attention : \(warning)")
                }
            }
        }
    }
}

#Preview {
    List {
        WarningsBanner(warnings: [
            "Le fouet doit être mis dès le début.",
            "Sortir le beurre 1 h avant.",
        ])
        // No warnings: the banner renders nothing at all.
        WarningsBanner(warnings: [])
    }
}
