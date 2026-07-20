import StoreKit
import SwiftUI

/// The subscription sheet: what Premium buys, what it costs, and the buying of
/// it. Prices come from the App Store — never hard-coded, they differ by
/// storefront and Apple raises them without asking us.
struct PremiumSheet: View {
    /// Optional so the sheet stays previewable offline: without a store it shows
    /// the offer it cannot sell, which is also what a network failure looks like.
    var store: SubscriptionStore? = nil

    @Environment(\.dismiss) private var dismiss
    /// The spec pushes the yearly price forward, so it is the pre-selected offer.
    @State private var selectedProductId = SubscriptionProducts.yearly

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
        .task { await store?.refresh() }
        .onChange(of: store?.isPremium) { _, isPremium in
            // The moment the server confirms Premium, the sheet has done its job.
            if isPremium == true { dismiss() }
        }
        .alert(
            "Une erreur est survenue",
            isPresented: Binding(
                get: { store?.errorMessage != nil },
                set: { if !$0 { store?.errorMessage = nil } }
            )
        ) {
            Button("OK") { store?.errorMessage = nil }
        } message: {
            Text(store?.errorMessage ?? "")
        }
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

    @ViewBuilder
    private var offers: some View {
        if store?.isLoading == true {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
        } else if products.isEmpty {
            // Loaded and still nothing: no network, or the products are not
            // available on this store. Say so rather than spin forever.
            VStack(spacing: Theme.Spacing.s) {
                Text("Les offres ne sont pas disponibles pour le moment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Réessayer") { Task { await store?.refresh() } }
                    .font(.subheadline)
                    .disabled(store == nil)
            }
            .padding(.vertical, Theme.Spacing.l)
        } else {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(products, id: \.id) { product in
                    OfferCard(
                        title: product.displayName,
                        price: product.displayPrice,
                        detail: detail(for: product),
                        badge: product.id == SubscriptionProducts.yearly ? "Économisez 30 %" : nil,
                        isSelected: selectedProductId == product.id
                    ) { selectedProductId = product.id }
                }
            }
        }
    }

    private var subscribeBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button {
                guard let store, let product = selectedProduct else { return }
                Task { await store.purchase(product) }
            } label: {
                // A CTA that hits the network shows it, right where it was tapped.
                if store?.isPurchasing == true {
                    ProgressView().tint(.white)
                } else {
                    Text(subscribeLabel)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(selectedProduct == nil || store?.isPurchasing == true)
            .accessibilityIdentifier("subscribe-button")

            Button("Restaurer mes achats") {
                guard let store else { return }
                Task { await store.restore() }
            }
            .font(.footnote)
            .disabled(store == nil || store?.isPurchasing == true)

            Text("Sans engagement, résiliable à tout moment depuis les réglages de l’iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .background(.bar)
    }

    private var products: [Product] {
        // Keep the declared order — yearly first, the offer we put forward.
        SubscriptionProducts.all.compactMap { id in store?.products.first { $0.id == id } }
    }

    private var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }

    /// The subscribe label says what actually happens: a free trial when the
    /// selected offer carries one, a payment otherwise.
    private var subscribeLabel: String {
        selectedProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
            ? "Essayer gratuitement"
            : "S’abonner"
    }

    /// The line under an offer: what a year costs per month, or the trial it opens with.
    private func detail(for product: Product) -> String {
        if let trial = product.subscription?.introductoryOffer, trial.paymentMode == .freeTrial {
            return "\(trial.period.value) \(trial.period.unit.frenchName) offerts, puis renouvellement automatique"
        }
        return "sans engagement"
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var frenchName: String {
        switch self {
        case .day: return "jours"
        case .week: return "semaines"
        case .month: return "mois"
        case .year: return "ans"
        @unknown default: return "jours"
        }
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
    // No store: the offline shape of the sheet — copy and layout, offers loading.
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PremiumSheet()
        }
}
