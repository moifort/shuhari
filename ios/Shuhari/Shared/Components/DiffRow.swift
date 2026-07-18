import SwiftUI

/// A single proposed parameter change: the param name and its `DiffValue` —
/// the highlighted diff on the proposition screen.
struct DiffRow: View {
    let key: String
    let from: String?
    let to: String

    var body: some View {
        HStack(spacing: 8) {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            DiffValue(from: from, to: to)
        }
        .font(.subheadline)
    }
}

#Preview {
    VStack(spacing: 12) {
        DiffRow(key: "Température", from: "93 °C", to: "92 °C")
        DiffRow(key: "Pré-infusion", from: nil, to: "5 s")
    }
    .padding()
}
