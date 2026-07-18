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

    init(gold: Int = 0, xp: Int = 0, owned: [String] = []) {
        self.gold = gold
        self.xp = xp
        self.owned = owned
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
        Reward(id: "vessel.eliksyras", name: "Potion Body", price: 60, symbol: "flask", kind: .vessel),
        Reward(id: "vessel.taure", name: "Glass Body", price: 90, symbol: "wineglass", kind: .vessel),
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
