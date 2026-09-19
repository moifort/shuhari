import SwiftUI

/// The row that leads a list which is already readable while it is being brought up
/// to date: the rows below stay in place and this one spins — the same circle a
/// pull-to-refresh draws, in the list's first row. What a cached library shows instead
/// of a loader taking the screen away from rows it already has.
///
/// The mirror of `LoadMoreRow`, which closes the list, with one difference: it never
/// starts the work itself. The refresh is already in flight by the time the row
/// appears, so a `.task` here would fetch the same page twice. It becomes a
/// "Réessayer" button when that refresh failed — otherwise nothing on screen would say
/// the rows are the ones from last time.
struct RefreshRow: View {
    let failed: Bool
    var loadingLabel: String = "Mise à jour de la liste"
    let onRetry: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            if failed {
                Button {
                    Task { await onRetry() }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("refresh-retry")
            } else {
                ProgressView()
                    .accessibilityLabel(loadingLabel)
                    .accessibilityIdentifier("refresh-spinner")
            }
            Spacer()
        }
        // The pull-to-refresh circle sits on the list's own background, not on a card:
        // a plain row would give this one the height and the white of a recipe.
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 6, trailing: 0))
        .listRowSeparator(.hidden)
    }
}

#Preview("Mise à jour") {
    List {
        RefreshRow(failed: false, onRetry: {})
        Text("Crème brûlée")
        Text("Poolish")
    }
}

#Preview("Échec") {
    List {
        RefreshRow(failed: true, onRetry: {})
        Text("Crème brûlée")
        Text("Poolish")
    }
}
