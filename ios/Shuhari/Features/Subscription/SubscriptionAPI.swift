import Apollo
import Foundation

/// What the server says a cook is entitled to. `appAccountToken` is the UUID a
/// purchase must carry to be recognised — the app never derives it, it asks.
struct EntitlementState: Sendable {
    let isPremium: Bool
    let appAccountToken: UUID?
    let productId: String?
    let expiresOn: Date?
}

enum SubscriptionAPI {
    static func load() async throws -> EntitlementState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.EntitlementQuery()
        )
        return state(
            plan: data.entitlement.plan,
            token: data.entitlement.appAccountToken,
            productId: data.entitlement.productId,
            expiresOn: data.entitlement.expiresOn
        )
    }

    /// Hand a transaction the App Store signed to the server, which verifies it
    /// and grants Premium. The only path to Premium there is.
    static func sync(signedTransaction: String) async throws -> EntitlementState {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.SyncEntitlementMutation(signedTransaction: signedTransaction)
        )
        return state(
            plan: data.syncEntitlement.plan,
            token: data.syncEntitlement.appAccountToken,
            productId: data.syncEntitlement.productId,
            expiresOn: data.syncEntitlement.expiresOn
        )
    }

    private static func state(
        plan: GraphQLEnum<ShuhariGraphQL.Plan>,
        token: String,
        productId: String?,
        expiresOn: String?
    ) -> EntitlementState {
        EntitlementState(
            isPremium: plan.value == .premium,
            appAccountToken: UUID(uuidString: token),
            productId: productId,
            expiresOn: expiresOn.flatMap { GraphQLHelpers.parseISO8601($0) }
        )
    }
}
