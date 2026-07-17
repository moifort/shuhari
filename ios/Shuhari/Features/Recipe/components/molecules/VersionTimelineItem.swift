import SwiftUI

/// One notch of the version timeline: a status icon on a vertical rail that
/// connects to the next notch, then the version's change (or origin), tags and
/// mean note. Designed as a List row with hidden separators — the rail is the
/// visual thread.
struct VersionTimelineItem: View {
    let number: Int
    let change: String?
    let originDetail: String?
    let averageNote: Double?
    let trialCount: Int
    let date: Date
    let isCurrent: Bool
    let isToTest: Bool
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: statusIcon)
                    .font(.body)
                    .foregroundStyle(statusColor)
                    .frame(width: 24, height: 24)
                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.s) {
                    Text("v\(number)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    if isCurrent {
                        StatusTag(kind: .current)
                    }
                    if isToTest {
                        StatusTag(kind: .toTest)
                    }
                    Spacer()
                    Text(date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(change?.isEmpty == false ? change! : "Version d’origine")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let originDetail, !originDetail.isEmpty {
                    Text(originDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(averageNote.map { "Notée \(NoteFormat.average($0)) · \(trialCount) essai\(trialCount > 1 ? "s" : "")" } ?? "Pas encore testée")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    private var statusIcon: String {
        if isCurrent { return "checkmark.seal.fill" }
        if isToTest { return "flask.fill" }
        return "circle.fill"
    }

    private var statusColor: Color {
        if isCurrent { return Theme.Status.current }
        if isToTest { return Theme.Status.toTest }
        return Color(.tertiaryLabel)
    }
}

#Preview {
    List {
        VersionTimelineItem(number: 4, change: "Température 93 → 92 °C", originDetail: "Extraction trop chaude.", averageNote: nil, trialCount: 0, date: Date(), isCurrent: false, isToTest: true)
        VersionTimelineItem(number: 3, change: "Mouture plus fine", originDetail: nil, averageNote: 4.0, trialCount: 2, date: Date(), isCurrent: true, isToTest: false)
        VersionTimelineItem(number: 1, change: nil, originDetail: nil, averageNote: 3.0, trialCount: 1, date: Date(), isCurrent: false, isToTest: false, isLast: true)
    }
}
