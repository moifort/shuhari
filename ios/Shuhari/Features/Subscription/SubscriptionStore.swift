import Foundation
import StoreKit

/// The app's whole relationship with the App Store: what is for sale, what the
/// cook owns, and the buying of it. Every purchase ends the same way — the signed
/// transaction goes to the server, which is what actually grants Premium. The
/// store never decides that on its own; `isPremium` is the server's answer.
@MainActor
@Observable
final class SubscriptionStore {
    /// The plan in force, as the server last told us. `nil` until it has.
    private(set) var isPremium: Bool?
    /// The offers, App Store prices and all. Empty while loading, and when the
    /// products cannot be reached (no network, or no StoreKit configuration).
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    /// Set when a purchase or a restore failed in a way worth telling about — a
    /// cancelled purchase is not one.
    var errorMessage: String?

    /// The UUID a purchase must carry so the server can tie it to this cook. It
    /// is derived server-side and fetched, never computed here: one algorithm,
    /// in one language.
    private var appAccountToken: UUID?
    /// `nonisolated` so `deinit` can cancel it: written once in `init`, read once
    /// when the store goes away, never concurrently.
    private nonisolated(unsafe) var updates: Task<Void, Never>?

    init() {
        // Renewals and revocations can land while the app is running — Apple
        // pushes them through this sequence, which must be listened to for the
        // whole lifetime of the app.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.send(update)
                if case .verified(let transaction) = update { await transaction.finish() }
            }
        }
    }

    deinit { updates?.cancel() }

    /// Read the plan from the server, load the offers, and report whatever the
    /// App Store already considers ours. Safe to call on every appearance.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        if let state = try? await SubscriptionAPI.load() {
            isPremium = state.isPremium
            appAccountToken = state.appAccountToken
        }
        products = (try? await Product.products(for: SubscriptionProducts.all)) ?? []
        // Re-arm what Apple already sold us: a reinstall, a new device, or a
        // renewal that happened while the app was closed.
        await syncCurrentEntitlements()
    }

    /// Buy one of the offers. Returns true when the cook came out of it Premium.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard let appAccountToken else {
            errorMessage = "Impossible de préparer l’achat. Réessaie dans un instant."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            switch result {
            case .success(let verification):
                await send(verification)
                if case .verified(let transaction) = verification { await transaction.finish() }
                return isPremium == true
            case .pending:
                // Ask-to-buy and other deferred approvals: nothing to do but wait
                // for Transaction.updates to fire.
                errorMessage = "Ton achat est en attente d’approbation."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    /// "Restaurer mes achats" — Apple requires the button to exist. Asking the
    /// App Store to resync is what recovers a subscription bought on another
    /// device; the entitlements it turns up are then sent to the server.
    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await syncCurrentEntitlements()
            if isPremium != true { errorMessage = "Aucun abonnement à restaurer sur ce compte." }
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Walk everything the App Store currently considers ours and hand it over.
    /// There is at most one subscription, but the sequence is the API.
    private func syncCurrentEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            await send(entitlement)
        }
    }

    /// The one path to Premium: the server verifies the signature and answers
    /// with the plan. An unverified result is not even sent — Apple already told
    /// us it does not check out.
    private func send(_ result: VerificationResult<Transaction>) async {
        guard case .verified = result else { return }
        guard let state = try? await SubscriptionAPI.sync(signedTransaction: result.jwsRepresentation)
        else { return }
        isPremium = state.isPremium
        appAccountToken = state.appAccountToken ?? appAccountToken
    }
}
