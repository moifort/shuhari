import SwiftUI

/// An essai's detail: note + remarks and an optional photo of the result.
struct TrialDetailPage: View {
    let recipeTitle: String
    let version: RecipeVersion

    var body: some View {
        List {
            if let photoUrl = version.photoUrl, let url = URL(string: photoUrl) {
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
                    NoteBadge(note: version.note ?? 0)
                    Text(version.remarks ?? "")
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Essai du \((version.executedAt ?? version.createdAt).formatted(.dateTime.day().month(.wide)))")
        .navigationSubtitle("\(recipeTitle) · v\(version.number)")
    }
}

#Preview {
    NavigationStack {
        TrialDetailPage(
            recipeTitle: Fixtures.bourguignon.title,
            version: Fixtures.bourguignonV3
        )
    }
}
