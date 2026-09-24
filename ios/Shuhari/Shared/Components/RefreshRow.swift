import SwiftUI

/// The row that leads a list whose background refresh failed: the rows below are the
/// ones from last time, and this "Réessayer" button is the only thing on screen that
/// says so. A refresh in flight draws nothing — the cached rows are already readable,
/// and a spinner over them at every tab switch was noise.
///
/// The mirror of the failed `LoadMoreRow`, which closes the list.
struct RefreshRow: View {
    let onRetry: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            Button {
                Task { await onRetry() }
            } label: {
                Label("Réessayer", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("refresh-retry")
            Spacer()
        }
        // Sits on the list's own background, not on a card: a plain row would give
        // this one the height and the white of a recipe.
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 6, trailing: 0))
        .listRowSeparator(.hidden)
    }
}

#Preview {
    List {
        RefreshRow(onRetry: {})
        Text("Crème brûlée")
        Text("Poolish")
    }
}
