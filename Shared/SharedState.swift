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

    /// Short mood line matching the fill level ("Ramu.", "Kaupiasi…", …).
    static var stateLine: String {
        get { defaults.string(forKey: "stateLine") ?? "Ramu." }
        set { defaults.set(newValue, forKey: "stateLine") }
    }
}
