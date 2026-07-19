import SwiftUI

/// One notch of the version timeline: a status icon on a vertical rail that
/// connects to the next notch, then the version's change (or origin), tags and
/// rating. Designed as a List row with hidden separators — the rail is the
/// visual thread.
struct VersionTimelineItem: View {
    let number: Int
    let change: String?
    let originDetail: String?
    let rating: Int?
    let tried: Bool
    let date: Date
    /// The version to open — "celle sur laquelle je travaille" — highlighted.
    let isFocus: Bool
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
                    if isFocus {
                        StatusTag(kind: .working)
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
                Text(attemptLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    private var attemptLabel: String {
        if let rating { return "Notée \(rating)/5" }
        return tried ? "Essayée" : "Pas encore essayée"
    }

    private var statusIcon: String {
        if isFocus { return "wrench.and.screwdriver.fill" }
        return "circle.fill"
    }

    private var statusColor: Color {
        if isFocus { return Theme.Status.attempt }
        return Color(.tertiaryLabel)
    }
}

#Preview {
    List {
        VersionTimelineItem(number: 4, change: "Température 93 → 92 °C", originDetail: "Extraction trop chaude.", rating: nil, tried: false, date: Date(), isFocus: true)
        VersionTimelineItem(number: 3, change: "Mouture plus fine", originDetail: nil, rating: 4, tried: true, date: Date(), isFocus: false)
        VersionTimelineItem(number: 1, change: nil, originDetail: nil, rating: 3, tried: true, date: Date(), isFocus: false, isLast: true)
    }
}
