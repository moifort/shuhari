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
    @ScaledMetric(relativeTo: .footnote) private var bulletSize: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: bulletSize)).foregroundStyle(.tertiary)
            configuration.title
        }
    }
}

#Preview {
    List {
        ChangelogEntryRow(
            version: "1.3",
            date: Date(),
            notes: [
                "Import d’une recette par photo.",
                "Réglages Thermomix affichés étape par étape.",
            ]
        )
    }
}
