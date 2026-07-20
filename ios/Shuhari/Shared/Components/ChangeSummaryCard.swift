import SwiftUI

/// What a version changes and why, as the card opening the screen that shows it —
/// the AI proposal and the version it becomes once accepted render the exact same
/// card. Dressed in the change accent in three shades: the summary at full
/// strength, the rationale softened, the row tinted behind them.
///
/// Composes as a `Section` directly inside a `List`. Either half can be missing
/// (an imported v1 carries no summary); with both empty the card renders nothing.
struct ChangeSummaryCard: View {
    let summary: String?
    let rationale: String?

    private var hasContent: Bool {
        summary?.isEmpty == false || rationale?.isEmpty == false
    }

    var body: some View {
        if hasContent {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if let summary, !summary.isEmpty {
                        Text(summary)
                            .font(.headline)
                            .foregroundStyle(Theme.Status.changed)
                    }
                    if let rationale, !rationale.isEmpty {
                        Text(rationale)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Status.changed.opacity(0.75))
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Theme.Status.changed.opacity(0.12))
        }
    }
}

#Preview {
    List {
        ChangeSummaryCard(
            summary: "Bouillon 50 → 40 cl, cuisson 3 h 30 → 4 h",
            rationale: "La sauce reste un peu liquide et la viande gagnerait à confire plus longtemps."
        )
        ChangeSummaryCard(summary: "Mouture plus fine", rationale: nil)
        ChangeSummaryCard(summary: nil, rationale: "Recette importée telle quelle.")
    }
}
