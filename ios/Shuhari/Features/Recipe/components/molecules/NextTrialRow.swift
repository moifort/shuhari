import SwiftUI

/// One compact "prochain essai" row: the change to apply as title, the reason with the version badge leading the subtitle, and a chevron affordance. Primitive-first — no domain struct.
struct NextTrialRow: View {
    let versionNumber: Int
    let change: String?
    let why: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(change?.isEmpty == false ? change! : "Version d’origine")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.s) {
                    StatusTag(kind: .version(versionNumber))
                    if let why, !why.isEmpty {
                        Text(why)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        NextTrialRow(versionNumber: 4, change: "Cuisson 3 h → 3 h 30", why: "La viande était encore un peu ferme.")
        NextTrialRow(versionNumber: 2, change: "Température 93 → 92 °C", why: nil)
        NextTrialRow(versionNumber: 1, change: nil, why: nil)
    }
}
