import ActivityKit
import Foundation

/// The cooking on the lock screen. Started when the oven accepts a start from the
/// app, re-anchored on every read of the oven the recipe sheet makes, ended when a
/// read finds the oven idle.
///
/// Between two reads nothing runs: the activity holds an END DATE, and the system
/// counts down to it on its own. A read only ever corrects that date — which is
/// why the app can sleep, locked in a pocket, through the whole cooking.
///
/// Local by choice: a cooking dialled in on the oven's own panel opens no
/// activity (the app does not know which recipe it is), and once the app is
/// asleep a stop on the oven only shows when the timer runs out. Server pushes
/// would close both gaps, at the price of an always-on listener — see
/// docs/ios-guide.md.
enum OvenActivityController {
    /// How far a fresh reading may drift from the end on screen before it moves it.
    /// The oven's remaining time arrives in whole minutes: re-anchoring on every
    /// read would make the countdown jump back up to a minute at each one.
    private static let tolerance: TimeInterval = 90

    /// How long a finished cooking stays on the lock screen — long enough to be
    /// seen when the phone is next picked up, not all evening.
    private static let lingering: TimeInterval = 30 * 60

    /// The activity on screen, if any. Read from the system rather than held: it
    /// outlives the sheet that opened it, and the app process too.
    private static var current: Activity<OvenActivityAttributes>? {
        Activity<OvenActivityAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    /// Put the cooking the oven just accepted on the lock screen. Replaces any
    /// cooking still showing: one oven, one cooking.
    static func start(title: String, oven: OvenState?) {
        Task { await begin(title: title, oven: oven, at: .now) }
    }

    /// Bring the activity in line with a fresh read of the oven. `settling` is a
    /// start the oven accepted but does not report yet: idle then means "not yet",
    /// not "over".
    static func follow(_ oven: OvenState, settling: Bool) {
        Task { await align(with: oven, settling: settling, at: .now) }
    }

    // The work itself runs off the main actor, where it was called from: an
    // `Activity` is not Sendable, so it is looked up, updated and ended in one
    // place rather than carried across an isolation boundary.

    private static func begin(title: String, oven: OvenState?, at now: Date) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // The oven usually still reads idle right after a start: the version's own
        // timer stands in until the first read that reports the cooking.
        let minutes = oven?.running?.remaining ?? oven?.settings.duration
        let state = OvenActivityAttributes.ContentState(
            program: oven?.settings.program?.rawValue,
            assisted: oven?.settings.assisted,
            temperature: oven?.settings.temperature,
            core: oven?.settings.core,
            startedAt: now,
            endsAt: minutes.map { now.addingTimeInterval(TimeInterval($0) * 60) },
            finished: false
        )
        for activity in Activity<OvenActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        _ = try? Activity.request(
            attributes: OvenActivityAttributes(title: title),
            content: ActivityContent(state: state, staleDate: state.endsAt)
        )
    }

    private static func align(with oven: OvenState, settling: Bool, at now: Date) async {
        guard let activity = current else { return }
        var state = activity.content.state
        guard let running = oven.running else {
            guard !settling else { return }
            state.finished = true
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(now.addingTimeInterval(lingering))
            )
            return
        }
        let endsAt = running.remaining.map { now.addingTimeInterval(TimeInterval($0) * 60) }
        switch (state.endsAt, endsAt) {
        case let (shown?, fresh?) where abs(shown.timeIntervalSince(fresh)) <= tolerance:
            break
        default:
            state.endsAt = endsAt
        }
        state.temperature = oven.settings.temperature ?? state.temperature
        state.core = oven.settings.core ?? state.core
        guard state != activity.content.state else { return }
        await activity.update(ActivityContent(state: state, staleDate: state.endsAt))
    }
}
