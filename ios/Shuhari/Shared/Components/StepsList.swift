import SwiftUI

/// Numbered recipe steps. `big` enlarges them for the hands-busy execution mode.
struct StepsList: View {
    let steps: [String]
    var big: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: big ? 16 : 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(big ? .title2 : .subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: big ? 28 : 20, alignment: .trailing)
                    Text(step)
                        .font(big ? .title3 : .body)
                }
            }
        }
    }
}

#Preview {
    StepsList(steps: [
        "Chauffer l'eau à 92 °C.",
        "Moudre 18,5 g de café fin.",
        "Pré-infuser 5 s puis extraire 27 s.",
    ])
    .padding()
}
