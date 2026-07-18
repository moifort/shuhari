import SwiftUI

/// One compact "prochain essai" row: the change to apply as title, with the
/// version badge pinned top-right on the title line, and the reason as subtitle.
/// No chevron. Primitive-first — no domain struct.
struct NextTrialRow: View {
    let versionNumber: Int
    let change: String?
    let why: String?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(change?.isEmpty == false ? change! : "Version d’origine")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                if let why, !why.isEmpty {
                    Text(why)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            StatusTag(kind: .version(versionNumber))
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
