import SwiftUI

/// The "À tester" section: one amber banner per recipe carrying a pending version.
struct ToTestSection: View {
    let items: [HomeTestItem]
    let onExecute: (HomeTestItem) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "À tester", count: items.count, tint: .orange)
                ForEach(items) { item in
                    TestBanner(
                        title: item.title,
                        versionNumber: item.versionNumber,
                        change: item.change,
                        why: item.why,
                        type: item.type,
                        onExecute: { onExecute(item) }
                    )
                }
            }
        }
    }
}

#Preview {
    ToTestSection(
        items: [
            .init(id: "1", title: "Espresso", type: .cafe, versionNumber: 4, change: "Température 93 → 92 °C", why: "Extraction trop chaude."),
        ],
        onExecute: { _ in }
    )
    .padding()
}
