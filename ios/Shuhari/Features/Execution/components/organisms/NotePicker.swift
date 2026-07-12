import SwiftUI

/// A 1–10 note selector: two rows of five circular buttons, each at least
/// 44 pt tall (HIG touch target), the selection filled with the accent colour.
struct NotePicker: View {
    @Binding var selection: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(1...10, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    Text("\(value)")
                        .font(.body.weight(.bold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selection == value ? Color.white : .secondary)
                        .background(
                            selection == value ? Color.accentColor : Color(.systemFill),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Note \(value) sur 10")
                .accessibilityAddTraits(selection == value ? .isSelected : [])
                .accessibilityIdentifier("note-\(value)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Note de l’essai")
    }
}

#Preview {
    @Previewable @State var note: Int? = 8
    List {
        NotePicker(selection: $note)
    }
}
