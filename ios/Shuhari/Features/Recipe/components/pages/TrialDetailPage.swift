import SwiftUI

/// A trial's detail: note + remarks and an optional photo of the result.
struct TrialDetailPage: View {
    let recipeTitle: String
    let trial: Trial

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
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Essai du \(trial.executedAt.formatted(.dateTime.day().month(.wide)))")
        .navigationSubtitle("\(recipeTitle) · v\(trial.versionNumber)")
    }
}

#Preview {
    NavigationStack {
        TrialDetailPage(
            recipeTitle: Fixtures.bourguignon.title,
            trial: Fixtures.bourguignonTrials[1]
        )
    }
}
