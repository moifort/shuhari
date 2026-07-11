import SwiftUI

/// A changelog row: version number, date and the list of notes.
struct ChangelogEntryRow: View {
    let version: String
    let date: Date?
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("v\(version)")
                    .font(.headline)
                Spacer()
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Label(note, systemImage: "circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .labelStyle(ChangelogBulletStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ChangelogBulletStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.tertiary)
            configuration.title
        }
    }
}
