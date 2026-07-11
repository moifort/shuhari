import SwiftUI

/// A trial's detail: note + remarks, optional photo, the target/real comparison,
/// and a button to replay it exactly.
struct TrialDetailPage: View {
    let recipeTitle: String
    let trial: Trial
    let versionTargets: [Param]
    let onReplay: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Essai du \(trial.executedAt.formatted(.dateTime.day().month(.wide)))")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text("\(recipeTitle) · version v\(trial.versionNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 14) {
                    NoteBadge(note: trial.note)
                    Text(trial.remarks)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(15)
                .carnetCard()

                if let photoUrl = trial.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Cible vs réel")
                    TrialComparisonTable(targets: versionTargets, real: trial.realParams)
                }

                Button(action: onReplay) {
                    Label("Refaire exactement cet essai", systemImage: "arrow.trianglehead.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("replay-trial-button")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Essai")
        .navigationBarTitleDisplayMode(.inline)
    }
}
