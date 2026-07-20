import SwiftUI

/// The "Abonnement" settings section: the plan in force and, on the free plan,
/// what is left of each AI meter this month. Primitive-first — it knows nothing
/// of the API types, only numbers and labels.
struct QuotaSection: View {
    /// One meter to show. `limit` absent means unlimited, so only `used` is shown.
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

    var body: some View {
        Section {
            LabeledContent("Formule") {
                Text(isPremium ? "Premium" : "Gratuite")
                    .foregroundStyle(isPremium ? Color.accentColor : .secondary)
            }
            ForEach(meters) { meter in
                QuotaMeterRow(title: meter.title, icon: meter.icon, used: meter.used, limit: meter.limit)
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

/// One meter: what it counts, how much is spent, and a bar when it is capped.
private struct QuotaMeterRow: View {
    let title: String
    let icon: String
    let used: Int
    let limit: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(valueLabel)
                    .font(.subheadline)
                    .foregroundStyle(isExhausted ? Color.red : .secondary)
                    .monospacedDigit()
            }
            if let limit {
                ProgressView(value: Double(min(used, limit)), total: Double(limit))
                    .tint(isExhausted ? .red : .accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    private var valueLabel: String {
        guard let limit else { return "Illimité" }
        return "\(used) / \(limit) ce mois-ci"
    }

    private var isExhausted: Bool {
        guard let limit else { return false }
        return used >= limit
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
