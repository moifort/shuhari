import SwiftUI

/// The "Abonnement" settings section: the plan in force, what is left of each AI
/// meter this month, and — on the free plan — the door to the Premium sheet.
/// Primitive-first: it knows nothing of the API types nor of the sheet, only
/// numbers, labels and a callback.
struct QuotaSection: View {
    /// One meter to show. `limit` absent means unlimited, so only the word is shown.
    struct Meter: Identifiable {
        let title: String
        let icon: String
        let used: Int
        let limit: Int?

        var id: String { title }
    }

    let isPremium: Bool
    let meters: [Meter]
    let renewsOn: Date?
    /// Opens the Premium sheet — the row only exists on the free plan.
    var onUpgrade: () -> Void = {}

    var body: some View {
        Section {
            LabeledContent("Formule") {
                Text(isPremium ? "Premium" : "Gratuite")
                    .foregroundStyle(isPremium ? Color.accentColor : .secondary)
            }
            ForEach(meters) { meter in
                QuotaMeterRow(title: meter.title, icon: meter.icon, used: meter.used, limit: meter.limit)
            }
            if !isPremium {
                Button(action: onUpgrade) {
                    Label {
                        Text("Découvrir Premium")
                    } icon: {
                        // Not sparkles: the iterations meter above already wears it.
                        Image(systemName: "crown.fill").foregroundStyle(Color.accentColor)
                    }
                }
                .accessibilityIdentifier("discover-premium-button")
            }
        } header: {
            Text("Abonnement")
        } footer: {
            if let renewsOn, !isPremium {
                Text("Vos compteurs repartent à zéro le \(Self.renewalLabel(renewsOn)).")
            } else if isPremium {
                Text("Aucune limite sur les appels à l’IA, import par lien compris.")
            }
        }
    }

    /// The renewal date is always the 1st of a month, so the day is spelled "1er".
    private static func renewalLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return "1er \(formatter.string(from: date))"
    }
}

/// One meter: what it counts on the left, what is left of it in plain words on
/// the right — "1 restant", "Épuisé", "Illimité" — and a thin gauge underneath
/// when the meter is capped.
private struct QuotaMeterRow: View {
    let title: String
    let icon: String
    let used: Int
    let limit: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(remainingLabel)
                    .font(.subheadline.weight(isExhausted ? .semibold : .regular))
                    .foregroundStyle(isExhausted ? Color.red : .secondary)
                    .monospacedDigit()
            }
            if let limit {
                ThinGauge(
                    fraction: Double(min(used, limit)) / Double(limit),
                    tint: isExhausted ? .red : .accentColor
                )
                .accessibilityLabel("\(used) sur \(limit) utilisés")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var remainingLabel: String {
        guard let limit else { return "Illimité" }
        let remaining = max(0, limit - used)
        if remaining == 0 { return "Épuisé" }
        return remaining == 1 ? "1 restant" : "\(remaining) restants"
    }

    private var isExhausted: Bool {
        guard let limit else { return false }
        return used >= limit
    }
}

/// A thin rounded bar filling up as the month is spent — full and red once the
/// meter is exhausted. Quieter than the system ProgressView in a list row.
private struct ThinGauge: View {
    /// Share of the allowance already spent, `0...1`.
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geometry.size.width * fraction))
            }
        }
        .frame(height: 5)
    }
}

#Preview("Gratuite") {
    List {
        QuotaSection(
            isPremium: false,
            meters: [
                .init(title: "Imports IA", icon: "square.and.arrow.down", used: 1, limit: 3),
                .init(title: "Itérations IA", icon: "sparkles", used: 5, limit: 5),
            ],
            renewsOn: Date(timeIntervalSince1970: 1_785_542_400)
        )
    }
}

#Preview("Premium") {
    List {
        QuotaSection(
            isPremium: true,
            meters: [
                .init(title: "Imports IA", icon: "square.and.arrow.down", used: 12, limit: nil),
                .init(title: "Itérations IA", icon: "sparkles", used: 47, limit: nil),
            ],
            renewsOn: Date(timeIntervalSince1970: 1_785_542_400)
        )
    }
}
