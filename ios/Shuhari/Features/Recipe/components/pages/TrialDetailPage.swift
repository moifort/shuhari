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
            if let photoUrl = trial.photoUrl, let url = URL(string: photoUrl) {
                Section {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 260)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Photo du résultat")
                }
            }

            Section {
                HStack(alignment: .top, spacing: 14) {
                    NoteBadge(note: trial.note)
                    Text(trial.remarks)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }

            TrialComparisonTable(targets: versionTargets, real: trial.realParams)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
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

#Preview {
    NavigationStack {
        TrialDetailPage(
            recipeTitle: Fixtures.espresso.title,
            trial: Fixtures.espressoTrials[1],
            versionTargets: Fixtures.espressoV3.params,
            onReplay: {}
        )
    }
}
