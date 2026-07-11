import SwiftUI

/// Displays an ordered list of recipe parameters as key/value rows with the
/// values in tabular monospace — the "posé sur le plan de travail" look.
struct ParamsGrid: View {
    struct Item: Identifiable {
        let id = UUID()
        let key: String
        let value: String
        var highlighted: Bool = false
    }

    let items: [Item]
    var big: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                HStack {
                    Text(item.key)
                        .font(big ? .title3 : .subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.value)
                        .font(.system(big ? .largeTitle : .body, design: .monospaced))
                        .fontWeight(big ? .semibold : .regular)
                        .foregroundStyle(item.highlighted ? Color.accentColor : .primary)
                }
                .padding(.vertical, big ? 12 : 8)
                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
    }
}

#Preview {
    ParamsGrid(items: [
        .init(key: "Dose", value: "18,5 g"),
        .init(key: "Température", value: "92 °C", highlighted: true),
        .init(key: "Mouture", value: "fine"),
    ])
    .padding()
}
