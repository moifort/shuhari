import Foundation

/// One AI meter for the current month. `limit` is absent on an unlimited plan —
/// the server says "no limit" with a null, and the app says it with `nil`.
struct QuotaCounter: Sendable {
    let used: Int
    let limit: Int?
    let remaining: Int?

    var isUnlimited: Bool { limit == nil }
}

/// What the cook is entitled to this month: the plan, both meters, and when they
/// go back to zero.
struct QuotaState: Sendable {
    let isPremium: Bool
    let imports: QuotaCounter
    let iterations: QuotaCounter
    let renewsOn: Date?
}
