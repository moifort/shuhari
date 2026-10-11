import SwiftUI

/// The connected oven, as one recipe sheet sees it. Loads its state when the sheet
/// opens, keeps it fresh while the sheet is there, and starts the cooking the
/// displayed version asks for.
///
/// `state == nil` after a load means this account owns no oven: the sheet then
/// shows no oven controls at all, rather than a button nobody could ever enable.
@MainActor
@Observable
final class OvenViewModel {
    private(set) var state: OvenState?
    var error = ErrorPresenter()

    /// When a cooking was last asked to start. The appliance reports through the
    /// cloud and takes a few seconds to admit it is RUNNING, so the reads right
    /// after a start are the quick ones.
    private var startedAt: Date?
    /// When the appliance was last read, whatever it answered — what the next read
    /// is due from.
    private var lastRead = Date.now

    /// True while the appliance is being asked. Read off the presenter rather than
    /// tracked twice: two flags for one wait is one flag too many.
    var isStarting: Bool { error.isRunning }

    /// Whether the recipe sheet should offer to start a cooking. An oven that does
    /// not answer, or refuses remote operation, still shows the button — pressing
    /// it is how the cook learns WHY, and the error says what to do about it.
    var isAvailable: Bool { state != nil }

    /// True while the oven reports a cooking under way — the button then says so
    /// instead of offering a second one.
    var isRunning: Bool { state?.running != nil }

    /// True from the moment the oven accepted a start until it reports the cooking.
    /// The appliance answers through the cloud and admits it is RUNNING only seconds
    /// later, so without this the button it just lit came back as "Lancer la
    /// cuisson" for that whole gap — an invitation to press it twice.
    private(set) var awaitingConfirmation = false

    /// The cooking to show: the one the oven reports, or — while a start it accepted
    /// is still settling — that one, ahead of the oven saying so. Gives up once the
    /// settling window is over, so a start the oven silently dropped brings the
    /// button back instead of claiming a cooking that never began.
    var run: OvenRun? {
        state?.running ?? (awaitingConfirmation ? OvenRun(remaining: nil) : nil)
    }

    /// Whether a start is recent enough to still be settling.
    private var isSettling: Bool {
        guard let startedAt else { return false }
        return Date.now.timeIntervalSince(startedAt) < 30
    }

    func load() async {
        lastRead = .now
        state = try? await OvenAPI.state()
        if let state { OvenActivityController.follow(state, settling: false) }
    }

    /// Keep asking the appliance for as long as the sheet is on screen. Nothing
    /// pushes: the oven answers a cloud API, so a cooking started here reads as
    /// RUNNING only seconds later — and one dialled in on the oven's own panel
    /// never reaches the sheet at all otherwise. Cancelled with the view's task,
    /// so nothing polls behind a screen nobody is looking at — and never started when
    /// the load found no oven: an account without one would otherwise ask every 30
    /// seconds, for as long as any recipe sheet stays open, for an answer that is
    /// always the same nothing.
    func watch() async {
        guard isAvailable else { return }
        while !Task.isCancelled {
            // Ticking every second and deciding here, rather than sleeping the whole
            // interval: pressing start shortens it, and a sleep already under way
            // would not hear about it — which is a cook watching an unchanged button
            // for half a minute.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            if awaitingConfirmation, !isSettling { awaitingConfirmation = false }
            guard Date.now.timeIntervalSince(lastRead) >= interval else { continue }
            await refresh()
        }
    }

    /// Seconds until the next read is due. Quick while a start is settling, slow the
    /// rest of the time: the appliance sits behind a rate-limited API and a recipe
    /// sheet can stay open all afternoon, while a running cooking only ever counts
    /// whole minutes down.
    private var interval: TimeInterval {
        guard !isRunning, isSettling else { return 30 }
        return 3
    }

    /// Read the state again without losing what is on screen: a read that fails
    /// means the network blinked, not that the oven vanished. Skipped while a start
    /// is in flight — that call answers with a fresher state than this one would.
    private func refresh() async {
        guard !isStarting else { return }
        lastRead = .now
        guard let fresh = try? await OvenAPI.state() else { return }
        state = fresh
        if fresh.running != nil { awaitingConfirmation = false }
        OvenActivityController.follow(fresh, settling: awaitingConfirmation)
    }

    /// Start the version's cooking. Reports the oven's refusal as a sentence rather
    /// than a code — `APIError` is what turns one into the other. An accepted start
    /// goes on the lock screen under the recipe's `title`.
    func start(recipeId: String, version: Int, title: String) async {
        await error.run {
            self.state = try await OvenAPI.start(recipeId: recipeId, version: version)
        } onSuccess: {
            // The oven has taken the command but usually still reads as idle. The
            // sheet shows the cooking at once, and the quick polls close the gap; a
            // refusal has no gap to close, and keeps the slow pace.
            self.startedAt = .now
            self.awaitingConfirmation = self.state?.running == nil
            OvenActivityController.start(title: title, oven: self.state)
        }
    }
}
