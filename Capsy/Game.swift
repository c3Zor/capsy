import Foundation
import SwiftData

// MARK: - Game state (the economy row)
//
// A single persisted row holds the whole economy: gold to spend, xp to level
// up, and the ids of owned shop rewards. There is only ever one of these — the
// Game facade fetches-or-creates it lazily.

@Model
final class GameState {
    var gold: Int
    var xp: Int
    var owned: [String]

    // Gentle streak (added after the initial schema — every new property
    // carries an inline default so SwiftData lightweight-migrates existing
    // rows without a custom migration plan).
    var lastRitualDay: String = ""
    var streakCount: Int = 0
    var streakFreezes: Int = 1

    init(
        gold: Int = 0,
        xp: Int = 0,
        owned: [String] = [],
        lastRitualDay: String = "",
        streakCount: Int = 0,
        streakFreezes: Int = 1
    ) {
        self.gold = gold
        self.xp = xp
        self.owned = owned
        self.lastRitualDay = lastRitualDay
        self.streakCount = streakCount
        self.streakFreezes = streakFreezes
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted after any economy mutation, so non-SwiftData observers can react.
    static let gameStateChanged = Notification.Name("gameStateChanged")
}

// MARK: - Game (gyva-tyla gamification layer)
//
// A thin facade over the single GameState row in AppDatabase's mainContext.
// The public API is unchanged from the old UserDefaults version, so every call
// site keeps compiling — only the storage moved into the real database.

@MainActor
enum Game {
    private static let defaults = UserDefaults.standard

    /// The single economy row, fetched-or-created on demand.
    ///
    /// One-time legacy migration: the very first time the row is created, it is
    /// seeded from any old UserDefaults "gold"/"xp"/"owned" values. Once the row
    /// exists those keys are never read again. (The cosmetic "hat" preference
    /// stays in UserDefaults/AppStorage — it is equip state, not economy.)
    private static var state: GameState {
        let context = AppDatabase.container.mainContext
        if let existing = try? context.fetch(FetchDescriptor<GameState>()),
           let row = existing.first {
            return row
        }
        let row = GameState(
            gold: defaults.integer(forKey: "gold"),
            xp: defaults.integer(forKey: "xp"),
            owned: defaults.stringArray(forKey: "owned") ?? []
        )
        context.insert(row)
        try? context.save()
        return row
    }

    /// Ensures the row exists (and legacy values migrate) at launch, so
    /// read-only @Query views show the balance before any economy write.
    static func bootstrap() {
        _ = state
    }

    /// Saves the context and notifies observers. Called after every mutation.
    private static func persist() {
        try? AppDatabase.container.mainContext.save()
        NotificationCenter.default.post(name: .gameStateChanged, object: nil)
    }

    static var gold: Int {
        get { state.gold }
        set { state.gold = newValue; persist() }
    }

    static var xp: Int {
        get { state.xp }
        set { state.xp = newValue; persist() }
    }

    /// Levels start at 1, one level per 100 xp.
    static var level: Int { xp / 100 + 1 }

    /// Fraction of progress toward the next level, for a progress bar.
    static var levelProgress: Double { Double(xp % 100) / 100 }

    private static var owned: Set<String> {
        get { Set(state.owned) }
        set { state.owned = Array(newValue); persist() }
    }

    static func earn(gold: Int, xp: Int) {
        let row = state
        row.gold += gold
        row.xp += xp
        persist()
    }

    /// Spends gold if there's enough. Returns whether the spend happened.
    static func spend(_ amount: Int) -> Bool {
        let row = state
        guard row.gold >= amount else { return false }
        row.gold -= amount
        persist()
        return true
    }

    static func owns(_ id: String) -> Bool {
        state.owned.contains(id)
    }

    /// Spends gold and records ownership. Returns whether the purchase happened.
    static func buy(_ id: String, price: Int) -> Bool {
        guard !owns(id), spend(price) else { return false }
        let row = state
        if !row.owned.contains(id) { row.owned.append(id) }
        persist()
        return true
    }

    // MARK: - Chest reward

    /// A variable-reward gold chest: mostly small, occasionally a windfall.
    /// Weighted 50% → 10g, 35% → 20g, 15% → 40g.
    static func chestReward() -> Int {
        switch Int.random(in: 0..<100) {
        case 0..<50: return 10
        case 50..<85: return 20
        default: return 40
        }
    }

    // MARK: - Gentle streak

    /// "yyyy-MM-dd" in the current calendar/timezone — the day key the streak is keyed on.
    private static func dayKey(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// Whole calendar days between two "yyyy-MM-dd" day keys, or nil if either fails to parse.
    private static func daysBetween(_ earlier: String, _ later: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let a = formatter.date(from: earlier), let b = formatter.date(from: later) else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day
    }

    /// Every 7th consecutive streak day banks a freeze, capped at 2 in reserve.
    private static func grantFreezeIfMilestone(_ row: GameState) {
        guard row.streakCount > 0, row.streakCount % 7 == 0 else { return }
        row.streakFreezes = min(2, row.streakFreezes + 1)
    }

    /// Registers today's ritual toward the gentle streak. Calm by design:
    /// - same day again → no-op (already counted)
    /// - the very next calendar day → streak +1
    /// - exactly one missed day, with a freeze in reserve → freeze is spent, streak is kept as-is
    /// - anything else (gap, or a missed day with no freeze) → streak resets to 1
    static func registerRitualDay() {
        let row = state
        let today = dayKey()
        guard row.lastRitualDay != today else { return }

        if row.lastRitualDay.isEmpty {
            row.streakCount = 1
        } else if let gap = daysBetween(row.lastRitualDay, today) {
            if gap == 1 {
                row.streakCount += 1
                grantFreezeIfMilestone(row)
            } else if gap == 2, row.streakFreezes > 0 {
                row.streakFreezes -= 1
            } else {
                row.streakCount = 1
            }
        } else {
            row.streakCount = 1
        }

        row.lastRitualDay = today
        persist()
    }

    static var streak: Int { state.streakCount }
    static var streakFreezes: Int { state.streakFreezes }
}

// MARK: - Reward catalog (shop items)

struct Reward: Identifiable {
    enum Kind { case vessel, hat }

    let id: String
    let name: String
    let price: Int
    let symbol: String
    let kind: Kind

    static let catalog: [Reward] = [
        Reward(id: "vessel.potion", name: "Potion Body", price: 60, symbol: "flask", kind: .vessel),
        Reward(id: "vessel.glass", name: "Glass Body", price: 90, symbol: "wineglass", kind: .vessel),
        Reward(id: "hat.leaf", name: "Leaf Hat", price: 40, symbol: "leaf.fill", kind: .hat),
        Reward(id: "hat.beanie", name: "Cozy Beanie", price: 70, symbol: "graduationcap.fill", kind: .hat),
        Reward(id: "hat.crown", name: "Tiny Crown", price: 150, symbol: "crown.fill", kind: .hat),
    ]
}

// MARK: - Habit seeding (the Habit @Model itself lives in HabitsView.swift)

extension Game {
    /// Seeds the four default habits once, the first time the shop/habits screen appears.
    static func seedHabitsIfNeeded(_ context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<Habit>())
        guard (existing ?? []).isEmpty else { return }

        let defaults: [(String, String)] = [
            ("Walk 10 min", "figure.walk"),
            ("Tea break", "cup.and.saucer.fill"),
            ("Stretch", "figure.flexibility"),
            ("Message a friend", "bubble.left.fill"),
        ]
        for (name, symbol) in defaults {
            context.insert(Habit(name: name, symbol: symbol))
        }
        try? context.save()
    }
}
