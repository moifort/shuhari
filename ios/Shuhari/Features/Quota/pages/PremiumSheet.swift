import SwiftUI

/// The subscription sheet — what Premium buys and what it costs. Purely
/// presentational for now: the prices are the ones decided in the pricing spec
/// (docs/specs/2026-07-20-freemium-pricing-design.md) and will come from the
/// StoreKit products once in-app purchase ships; until then the subscribe CTA
/// is the only thing missing, and it says so.
struct PremiumSheet: View {
    private enum Offer: String, CaseIterable, Identifiable {
        case yearly
        case monthly

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    /// The spec pushes the yearly price forward, so it is the pre-selected offer.
    @State private var offer: Offer = .yearly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    header
                    benefits
                    offers
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.m)
            }
            .safeAreaInset(edge: .bottom) { subscribeBar }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fermer")
                }
            }
        }
        // Full height only: at .medium the offers sit below the fold, and a
        // subscription sheet that hides its prices is not one.
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(premiumGradient)
                .accessibilityHidden(true)
            Text("Shuhari Premium")
                .font(.title2.bold())
            Text("L’IA en cuisine, sans compter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            BenefitRow(
                icon: "square.and.arrow.down",
                title: "Imports IA illimités",
                detail: "Photos, texte — autant de recettes que tu veux."
            )
            BenefitRow(
                icon: "sparkles",
                title: "Itérations IA illimitées",
                detail: "Propositions, améliorations et astuces sans quota."
            )
            BenefitRow(
                icon: "link",
                title: "Import par lien web",
                detail: "Colle l’adresse d’une recette, l’IA lit la page."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Offers

    private var offers: some View {
        VStack(spacing: Theme.Spacing.s) {
            OfferCard(
                title: "Annuel",
                price: "24,99 € / an",
                detail: "soit 2,08 € par mois",
                badge: "Économisez 30 %",
                isSelected: offer == .yearly
            ) { offer = .yearly }
            OfferCard(
                title: "Mensuel",
                price: "2,99 € / mois",
                detail: "sans engagement",
                badge: nil,
                isSelected: offer == .monthly
            ) { offer = .monthly }
        }
    }

    private var subscribeBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            // Not a network CTA waiting in silence: the purchase itself does not
            // exist yet, and the caption below owns up to it.
            Button("S’abonner") {}
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(true)
            Text("Bientôt disponible — l’abonnement arrive dans une prochaine version.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .background(.bar)
    }
}

/// The gradient the Premium identity wears — the AI sparkle warmed up, shared by
/// the header icon and any Premium accent.
private let premiumGradient = LinearGradient(
    colors: [.orange, .pink, .purple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

/// One thing Premium buys: icon, name, one line of detail.
private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One selectable price. A card, not a list row: the selected offer wears the
/// accent border, the other stays quiet.
private struct OfferCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.s) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
            .padding(Theme.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color(.separator),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PremiumSheet()
        }
}
