import SwiftUI

/// A 1–10 note selector rendered as a row of square buttons.
struct NotePicker: View {
    @Binding var selection: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 10)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(1...10, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    Text("\(value)")
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(selection == value ? Color.white : .secondary)
                        .background(
                            selection == value ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator).opacity(0.4)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("note-\(value)")
            }
        }
    }
}

#Preview {
    @Previewable @State var note: Int? = 8
    NotePicker(selection: $note).padding()
}
