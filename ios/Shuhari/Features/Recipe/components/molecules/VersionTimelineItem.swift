import SwiftUI

/// One node of the history timeline: a dot on a rail plus a card describing the
/// version (change or origin, badges, mean note).
struct VersionTimelineItem: View {
    let number: Int
    let change: String?
    let originDetail: String?
    let averageNote: Double?
    let trialCount: Int
    let date: Date
    let isCurrent: Bool
    let isToTest: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2))
                    .padding(.top, 6)
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("v\(number)")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    if isCurrent {
                        Label("courante", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    if isToTest {
                        Label("à tester", systemImage: "flask.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(change?.isEmpty == false ? change! : "Version d’origine")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                if let originDetail, !originDetail.isEmpty {
                    Text(originDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(averageNote.map { String(format: "Notée %.1f/10 · %d essai(s)", $0, trialCount).replacingOccurrences(of: ".", with: ",") } ?? "Pas encore testée")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .carnetCard()
            .padding(.bottom, 10)
        }
    }

    private var dotColor: Color {
        if isCurrent { return .green }
        if isToTest { return .orange }
        return Color(.tertiaryLabel)
    }
}
