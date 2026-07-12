import SwiftUI

/// The "À tester" section: one banner row per recipe carrying a pending version.
/// Composes as a `Section` directly inside a `List`.
struct ToTestSection: View {
    let items: [HomeTestItem]
    let onExecute: (HomeTestItem) -> Void

    var body: some View {
        if !items.isEmpty {
            Section("À tester") {
                ForEach(items) { item in
                    TestBanner(
                        title: item.title,
                        versionNumber: item.versionNumber,
                        change: item.change,
                        why: item.why,
                        onExecute: { onExecute(item) }
                    )
                }
            }
        }
    }
}

#Preview {
    List {
        ToTestSection(
            items: [
                .init(id: "1", title: "Espresso", type: .cafe, versionNumber: 4, change: "Température 93 → 92 °C", why: "Extraction trop chaude."),
            ],
            onExecute: { _ in }
        )
    }
}
