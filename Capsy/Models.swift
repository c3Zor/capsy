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

    static func stateLine(for fraction: Double) -> String {
        switch fraction {
        case 0:        "Ramu."
        case ..<0.4:   "Šiek tiek kaupiasi."
        case ..<0.8:   "Kaupiasi…"
        case ..<1.0:   "Jau sunku. Gal išpilti?"
        default:       "Pilnas. Laikas išpilti."
        }
    }

    /// Mirrors the current state to the App Group so widgets stay live.
    static func syncWidget(fraction: Double) {
        SharedState.fillFraction = fraction
        SharedState.stateLine = stateLine(for: fraction)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Intensity presentation

enum Intensity: Int, CaseIterable, Identifiable {
    case lengvas = 1, vidutinis = 2, sunkus = 3
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .lengvas: "Lengvas"
        case .vidutinis: "Vidutinis"
        case .sunkus: "Sunkus"
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
        Milestone(releases: 1,  title: "Pirmas atodūsis", symbol: "drop.fill"),
        Milestone(releases: 3,  title: "Tylos takelis",   symbol: "leaf.fill"),
        Milestone(releases: 7,  title: "Rami savaitė",    symbol: "moon.stars.fill"),
        Milestone(releases: 15, title: "Gilus vanduo",    symbol: "water.waves"),
        Milestone(releases: 30, title: "Gyva tyla",       symbol: "sparkles"),
    ]

    static func next(after count: Int) -> Milestone? {
        milestones.first { $0.releases > count }
    }
}
