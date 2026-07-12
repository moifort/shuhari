import SwiftUI

/// Displays an ordered list of recipe parameters as key/value rows. The compact
/// variant renders native `LabeledContent` rows (List/Form-friendly); the `big`
/// variant keeps the oversized hands-busy layout for the execution screen.
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
        if big {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack {
                        Text(item.key)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.value)
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(item.highlighted ? Color.accentColor : .primary)
                    }
                    .padding(.vertical, 12)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        } else {
            ForEach(items) { item in
                LabeledContent(item.key) {
                    Text(item.value)
                        .monospacedDigit()
                        .foregroundStyle(item.highlighted ? Color.accentColor : .primary)
                }
            }
        }
    }
}

#Preview {
    List {
        ParamsGrid(items: [
            .init(key: "Dose", value: "18,5 g"),
            .init(key: "Température", value: "92 °C", highlighted: true),
            .init(key: "Mouture", value: "fine"),
        ])
    }
}
