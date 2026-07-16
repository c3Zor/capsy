import Foundation
import SwiftData
import WidgetKit

// MARK: - SwiftData models

/// One logged stressful moment. It stays in the bucket until released.
@Model
final class StressDrop {
    var date: Date
    var intensity: Int      // 1 lengvas · 2 vidutinis · 3 sunkus
    var note: String
    var released: Bool

    /// How much liquid this drop adds to the bucket.
    var units: Int { intensity * 2 }

    init(intensity: Int, note: String = "") {
        self.date = .now
        self.intensity = intensity
        self.note = note
        self.released = false
    }
}

/// One completed breathing ritual that emptied the bucket.
@Model
final class ReleaseSession {
    var date: Date
    var cycles: Int
    var drainedUnits: Int

    init(cycles: Int, drainedUnits: Int) {
        self.date = .now
        self.cycles = cycles
        self.drainedUnits = drainedUnits
    }
}

// MARK: - Bucket logic (derived state, never stored)

enum Bucket {
    static let capacity = 24

    static func level(of drops: [StressDrop]) -> Int {
        min(capacity, drops.filter { !$0.released }.map(\.units).reduce(0, +))
    }

    static func fraction(of drops: [StressDrop]) -> Double {
        Double(level(of: drops)) / Double(capacity)
    }

    /// Haiku rhythm, ALL CAPS — the design book's tone of voice.
    /// Lives in SharedState so the widget's quick-drop intent can reuse it.
    static func stateLine(for fraction: Double) -> String {
        SharedState.line(for: fraction)
    }

    /// Mirrors the current state to the App Group so widgets stay live,
    /// and arms/cancels the "full vessel" nudge.
    static func syncWidget(fraction: Double) {
        SharedState.fillFraction = fraction
        SharedState.stateLine = stateLine(for: fraction)
        WidgetCenter.shared.reloadAllTimelines()
        Reminders.nudgeWhenFull(fraction: fraction)
    }
}

// MARK: - Intensity presentation

enum Intensity: Int, CaseIterable, Identifiable {
    case lengvas = 1, vidutinis = 2, sunkus = 3
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .lengvas: "Light"
        case .vidutinis: "Medium"
        case .sunkus: "Heavy"
        }
    }
}

// MARK: - Journey (Ramybės kelias)

struct Milestone: Identifiable {
    let releases: Int
    let title: String
    let symbol: String
    var id: Int { releases }
}

enum Journey {
    static let milestones: [Milestone] = [
        Milestone(releases: 1,  title: "First Exhale",    symbol: "drop.fill"),
        Milestone(releases: 3,  title: "Path of Silence", symbol: "leaf.fill"),
        Milestone(releases: 7,  title: "A Quiet Week",    symbol: "moon.stars.fill"),
        Milestone(releases: 15, title: "Deep Water",      symbol: "water.waves"),
        Milestone(releases: 30, title: "Living Silence",  symbol: "sparkles"),
    ]

    static func next(after count: Int) -> Milestone? {
        milestones.first { $0.releases > count }
    }
}
