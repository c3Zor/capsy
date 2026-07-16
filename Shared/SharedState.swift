import Foundation

/// Bucket state shared between the app and the widget through the App Group.
/// Falls back to standard UserDefaults if the group is unavailable (e.g. unsigned build),
/// so the app never crashes — the widget simply shows its own last-known state.
enum SharedState {
    static let appGroup = "group.com.capsy.shared"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Current bucket fill, 0.0 (empty) … 1.0 (full).
    static var fillFraction: Double {
        get { defaults.double(forKey: "fillFraction") }
        set { defaults.set(newValue, forKey: "fillFraction") }
    }

    /// Short mood line matching the fill level ("CALM.", "FILLING UP…", …).
    static var stateLine: String {
        get { defaults.string(forKey: "stateLine") ?? "CALM." }
        set { defaults.set(newValue, forKey: "stateLine") }
    }

    /// Drops logged from the interactive widget, waiting for the app to
    /// absorb them into SwiftData on next launch/foreground.
    static var pendingQuickDrops: Int {
        get { defaults.integer(forKey: "pendingQuickDrops") }
        set { defaults.set(newValue, forKey: "pendingQuickDrops") }
    }

    /// Haiku rhythm, ALL CAPS — shared so both the app and the widget's
    /// quick-drop intent produce the same line.
    static func line(for fraction: Double) -> String {
        switch fraction {
        case 0:        "CALM."
        case ..<0.4:   "A LITTLE IS GATHERING."
        case ..<0.8:   "FILLING UP…"
        case ..<1.0:   "GETTING HEAVY."
        default:       "FULL. TIME TO POUR."
        }
    }
}
