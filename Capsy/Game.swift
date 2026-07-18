import Foundation
import SwiftData

// MARK: - Game (gyva-tyla gamification layer)
//
// Thin UserDefaults-backed progress: gold to spend, xp to level up.
// No third-party deps, no persistence beyond UserDefaults + SwiftData habits.

enum Game {
    private static let defaults = UserDefaults.standard

    static var gold: Int {
        get { defaults.integer(forKey: "gold") }
        set { defaults.set(newValue, forKey: "gold") }
    }

    static var xp: Int {
        get { defaults.integer(forKey: "xp") }
        set { defaults.set(newValue, forKey: "xp") }
    }

    /// Levels start at 1, one level per 100 xp.
    static var level: Int { xp / 100 + 1 }

    /// Fraction of progress toward the next level, for a progress bar.
    static var levelProgress: Double { Double(xp % 100) / 100 }

    private static var owned: Set<String> {
        get { Set(defaults.stringArray(forKey: "owned") ?? []) }
        set { defaults.set(Array(newValue), forKey: "owned") }
    }

    static func earn(gold: Int, xp: Int) {
        Game.gold += gold
        Game.xp += xp
    }

    /// Spends gold if there's enough. Returns whether the spend happened.
    static func spend(_ amount: Int) -> Bool {
        guard gold >= amount else { return false }
        gold -= amount
        return true
    }

    static func owns(_ id: String) -> Bool {
        owned.contains(id)
    }

    /// Spends gold and records ownership. Returns whether the purchase happened.
    static func buy(_ id: String, price: Int) -> Bool {
        guard !owns(id), spend(price) else { return false }
        owned.insert(id)
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
