import SwiftUI

/// The "à tester" hero cards: one per recipe carrying a pending version. The
/// cards draw their own chrome, so the rows are cleared of list styling.
/// Composes as a `Section` directly inside a `List`.
struct ToTestSection: View {
    let items: [HomeTestItem]
    let onExecute: (HomeTestItem) -> Void

    var body: some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    TestBanner(
                        title: item.title,
                        versionNumber: item.versionNumber,
                        change: item.change,
                        why: item.why,
                        type: item.type,
                        onExecute: { onExecute(item) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}

#Preview {
    List {
        ToTestSection(
            items: [
                .init(id: "1", title: "Bœuf bourguignon", type: .plat, category: .plat, versionNumber: 4, change: "Cuisson 3 h → 3 h 30", why: "Viande encore ferme."),
            ],
            onExecute: { _ in }
        )
    }
}
