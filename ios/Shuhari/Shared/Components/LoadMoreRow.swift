import SwiftUI

/// Pagination sentinel row: triggers the next page as it appears, and becomes a
/// "Réessayer" button if the page failed — otherwise the spinner would spin forever
/// without retrying.
struct LoadMoreRow: View {
    let failed: Bool
    let loadingLabel: String
    let onLoadMore: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            if failed {
                Button {
                    Task { await onLoadMore() }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("load-more-retry")
            } else {
                ProgressView()
                    .accessibilityLabel(loadingLabel)
                    .task { await onLoadMore() }
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}

#Preview("Chargement") {
    List {
        LoadMoreRow(failed: false, loadingLabel: "Chargement d’autres recettes", onLoadMore: {})
    }
}

#Preview("Échec") {
    List {
        LoadMoreRow(failed: true, loadingLabel: "Chargement d’autres recettes", onLoadMore: {})
    }
}
