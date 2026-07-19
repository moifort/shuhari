import SwiftUI

/// Numbered recipe steps. `big` enlarges them for the hands-busy execution mode.
/// The compact variant renders one row per step (List/Form-friendly).
struct StepsList: View {
    let steps: [String]
    var big: Bool = false
    /// Step indices changed vs the previous version — flagged with a leading
    /// orange dot. Empty (the default) renders exactly like the plain recipe sheet.
    var modified: Set<Int> = []

    var body: some View {
        if big {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    row(index: index, step: step)
                }
            }
        } else {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                row(index: index, step: step)
            }
        }
    }

    private func row(index: Int, step: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if !modified.isEmpty {
                Circle()
                    .fill(modified.contains(index) ? Theme.Status.changed : .clear)
                    .frame(width: 7, height: 7)
            }
            Text("\(index + 1)")
                .font((big ? Font.title2 : .subheadline).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: big ? 28 : 20, alignment: .trailing)
            Text(step)
                .font(big ? .title3 : .body)
        }
    }
}

#Preview {
    List {
        StepsList(steps: [
            "Chauffer l'eau à 92 °C.",
            "Moudre 18,5 g de café fin.",
            "Pré-infuser 5 s puis extraire 27 s.",
        ])
    }
}
