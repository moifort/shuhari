import Apollo
import Foundation

enum QuotaAPI {
    /// The AI allowance for the current month — the plan, both meters and the
    /// renewal date.
    static func load() async throws -> QuotaState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.QuotaQuery()
        )
        let quota = data.quota
        return QuotaState(
            isPremium: quota.plan.value == .premium,
            imports: counter(used: quota.imports.used, limit: quota.imports.limit, remaining: quota.imports.remaining),
            iterations: counter(used: quota.iterations.used, limit: quota.iterations.limit, remaining: quota.iterations.remaining),
            renewsOn: GraphQLHelpers.parseISO8601(quota.renewsOn)
        )
    }

    private static func counter(used: Int, limit: Int?, remaining: Int?) -> QuotaCounter {
        QuotaCounter(used: used, limit: limit, remaining: remaining)
    }
}
