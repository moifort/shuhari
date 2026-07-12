import SwiftUI

/// A trial's detail: note + remarks, optional photo, the target/real comparison,
/// and a pinned button to replay it exactly.
struct TrialDetailPage: View {
    let recipeTitle: String
    let trial: Trial
    let versionTargets: [Param]
    let onReplay: () -> Void

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    NoteBadge(note: trial.note)
                    Text(trial.remarks)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }

            if let photoUrl = trial.photoUrl, let url = URL(string: photoUrl) {
                Section {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 220)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                }
            }

            TrialComparisonTable(targets: versionTargets, real: trial.realParams)
        }
        .navigationTitle("Essai du \(trial.executedAt.formatted(.dateTime.day().month(.wide)))")
        .navigationSubtitle("\(recipeTitle) · v\(trial.versionNumber)")
        .safeAreaInset(edge: .bottom) {
            Button(action: onReplay) {
                Label("Refaire exactement cet essai", systemImage: "arrow.trianglehead.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .accessibilityIdentifier("replay-trial-button")
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
