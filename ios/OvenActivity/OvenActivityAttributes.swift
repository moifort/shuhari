import ActivityKit
import Foundation

/// The cooking the lock screen follows. Compiled into the app, which starts and
/// updates the activity, AND into the widget extension, which draws it — the two
/// processes only ever agree through this one type.
///
/// The state carries the oven's technical values, never a sentence: the program
/// is `OvenProgram`'s raw symbol, translated where it is drawn. The day the server
/// pushes these updates itself, it speaks the same English symbols as the schema.
struct OvenActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// `OvenProgram.rawValue` — `convection`, `assisted`…
        var program: String?
        /// The oven's own programme code beside `program: assisted`.
        var assisted: String?
        /// The target temperature, °C.
        var temperature: Int?
        /// The probe's target, °C, on a cooking that stops at a core temperature.
        var core: Int?
        /// When the cooking began — what a cooking without a timer counts up from.
        var startedAt: Date
        /// When the oven's timer runs out, nil on a cooking without one. A date
        /// rather than minutes left: the system counts down to it on its own, with
        /// the app asleep, which is the whole point of a lock-screen timer.
        var endsAt: Date?
        /// The oven reported the cooking over.
        var finished: Bool
    }

    /// The recipe being cooked.
    var title: String
}
