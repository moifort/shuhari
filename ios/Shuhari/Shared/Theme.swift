import SwiftUI

/// Design tokens — the single source of truth for status colours, corner radii
/// and spacing. Semantic names carry the business state, so one state is never
/// two different colours across screens.
enum Theme {
    enum Status {
        /// The essai domain accent — the version in progress, AI propositions and
        /// the modifications they carry.
        static let essai = Color.orange
        /// A value that differs from the reference (diffs, deviations, highlights) —
        /// shares the essai accent, since a modification is what an essai is about.
        static let changed = Self.essai
        /// Thermomix machine settings.
        static let tmx = Color.teal

        /// Essai note thresholds: ≥ 4 high, 3 medium, ≤ 2 low.
        static func note(_ note: Int) -> Color {
            if note >= 4 { .green } else if note == 3 { .orange } else { .red }
        }
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 20
        static let overlay: CGFloat = 24
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
    }
}
