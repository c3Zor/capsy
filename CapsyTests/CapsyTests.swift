import XCTest
@testable import Capsy

/// Pure-logic tests only — no SwiftData containers, no UI, no Game economy.
/// StressDrop is a @Model class, but its plain `init` and stored properties
/// (date/intensity/note/released) can be read without inserting into a
/// ModelContext, so we build plain in-memory instances here.
final class CapsyTests: XCTestCase {

    // MARK: - Bucket.level / fraction / stateLine

    /// Note: StressDrop.units = intensity * 2, so any sum of drop units is
    /// necessarily even — an exact 23-unit total is unreachable through the
    /// real model. We use 22 (just under the 24 capacity) as the nearest
    /// achievable stand-in for that boundary, and cover the literal 23
    /// boundary separately via SharedState.line(for:) below.
    func testBucketLevel_empty() {
        XCTAssertEqual(Bucket.level(of: []), 0)
    }

    func testBucketLevel_twelveUnits() {
        // Two heavy drops: 6 + 6 = 12
        let drops = [StressDrop(intensity: 3), StressDrop(intensity: 3)]
        XCTAssertEqual(Bucket.level(of: drops), 12)
    }

    func testBucketLevel_justUnderCapacity() {
        // 3 heavy (18) + 2 light (4) = 22, just under the 24 cap.
        let drops = [
            StressDrop(intensity: 3), StressDrop(intensity: 3), StressDrop(intensity: 3),
            StressDrop(intensity: 1), StressDrop(intensity: 1),
        ]
        XCTAssertEqual(Bucket.level(of: drops), 22)
    }

    func testBucketLevel_atCapacity() {
        // 4 heavy drops: 6 * 4 = 24, exactly at capacity.
        let drops = Array(repeating: StressDrop(intensity: 3), count: 4)
        XCTAssertEqual(Bucket.level(of: drops), 24)
    }

    func testBucketLevel_overCapacityIsClamped() {
        // 4 heavy + 1 light = 24 + 2 = 26 raw units, clamped to capacity 24.
        var drops = Array(repeating: StressDrop(intensity: 3), count: 4)
        drops.append(StressDrop(intensity: 1))
        XCTAssertEqual(Bucket.level(of: drops), 24)
    }

    func testBucketLevel_ignoresReleasedDrops() {
        let released = StressDrop(intensity: 3)
        released.released = true
        let active = StressDrop(intensity: 2)
        XCTAssertEqual(Bucket.level(of: [released, active]), 4)
    }

    func testBucketFraction_empty() {
        XCTAssertEqual(Bucket.fraction(of: []), 0.0)
    }

    func testBucketFraction_twelveUnits() {
        let drops = [StressDrop(intensity: 3), StressDrop(intensity: 3)]
        XCTAssertEqual(Bucket.fraction(of: drops), 0.5, accuracy: 0.0001)
    }

    func testBucketFraction_atCapacity() {
        let drops = Array(repeating: StressDrop(intensity: 3), count: 4)
        XCTAssertEqual(Bucket.fraction(of: drops), 1.0, accuracy: 0.0001)
    }

    func testBucketFraction_overCapacityClampsToOne() {
        var drops = Array(repeating: StressDrop(intensity: 3), count: 4)
        drops.append(StressDrop(intensity: 1))
        XCTAssertEqual(Bucket.fraction(of: drops), 1.0, accuracy: 0.0001)
    }

    func testBucketStateLine_empty() {
        XCTAssertEqual(Bucket.stateLine(for: Bucket.fraction(of: [])), "CALM.")
    }

    func testBucketStateLine_twelveUnits() {
        let drops = [StressDrop(intensity: 3), StressDrop(intensity: 3)]
        XCTAssertEqual(Bucket.stateLine(for: Bucket.fraction(of: drops)), "FILLING UP…")
    }

    func testBucketStateLine_justUnderCapacity() {
        let drops = [
            StressDrop(intensity: 3), StressDrop(intensity: 3), StressDrop(intensity: 3),
            StressDrop(intensity: 1), StressDrop(intensity: 1),
        ]
        XCTAssertEqual(Bucket.stateLine(for: Bucket.fraction(of: drops)), "GETTING HEAVY.")
    }

    func testBucketStateLine_atCapacity() {
        let drops = Array(repeating: StressDrop(intensity: 3), count: 4)
        XCTAssertEqual(Bucket.stateLine(for: Bucket.fraction(of: drops)), "FULL. TIME TO POUR.")
    }

    func testBucketStateLine_overCapacityStillFull() {
        var drops = Array(repeating: StressDrop(intensity: 3), count: 4)
        drops.append(StressDrop(intensity: 1))
        XCTAssertEqual(Bucket.stateLine(for: Bucket.fraction(of: drops)), "FULL. TIME TO POUR.")
    }

    // MARK: - Intensity.units mapping (via StressDrop.units = intensity * 2)

    func testIntensityUnitsMapping() {
        XCTAssertEqual(StressDrop(intensity: Intensity.light.rawValue).units, 2)
        XCTAssertEqual(StressDrop(intensity: Intensity.medium.rawValue).units, 4)
        XCTAssertEqual(StressDrop(intensity: Intensity.heavy.rawValue).units, 6)
    }

    func testIntensityTitles() {
        XCTAssertEqual(Intensity.light.title, "Light")
        XCTAssertEqual(Intensity.medium.title, "Medium")
        XCTAssertEqual(Intensity.heavy.title, "Heavy")
    }

    // MARK: - SharedState.line(for:) thresholds

    func testSharedStateLine_zero() {
        XCTAssertEqual(SharedState.line(for: 0), "CALM.")
    }

    func testSharedStateLine_justAboveZero() {
        XCTAssertEqual(SharedState.line(for: 0.01), "A LITTLE IS GATHERING.")
    }

    func testSharedStateLine_belowFortyPercent() {
        XCTAssertEqual(SharedState.line(for: 0.39), "A LITTLE IS GATHERING.")
    }

    func testSharedStateLine_atFortyPercent() {
        XCTAssertEqual(SharedState.line(for: 0.4), "FILLING UP…")
    }

    func testSharedStateLine_midRange() {
        XCTAssertEqual(SharedState.line(for: 0.5), "FILLING UP…")
    }

    func testSharedStateLine_atEightyPercent() {
        XCTAssertEqual(SharedState.line(for: 0.8), "GETTING HEAVY.")
    }

    func testSharedStateLine_justUnderCapacityBoundary() {
        // The literal 23/24 boundary called out in the spec.
        XCTAssertEqual(SharedState.line(for: 23.0 / 24.0), "GETTING HEAVY.")
    }

    func testSharedStateLine_justBelowOne() {
        XCTAssertEqual(SharedState.line(for: 0.99), "GETTING HEAVY.")
    }

    func testSharedStateLine_atOne() {
        XCTAssertEqual(SharedState.line(for: 1.0), "FULL. TIME TO POUR.")
    }

    func testSharedStateLine_aboveOne() {
        XCTAssertEqual(SharedState.line(for: 1.5), "FULL. TIME TO POUR.")
    }

    // MARK: - Journey.next(after:)

    func testJourneyNext_afterZero() {
        XCTAssertEqual(Journey.next(after: 0)?.title, "First Exhale")
    }

    func testJourneyNext_afterOne() {
        XCTAssertEqual(Journey.next(after: 1)?.title, "Path of Silence")
    }

    func testJourneyNext_afterTwentyNine() {
        XCTAssertEqual(Journey.next(after: 29)?.title, "Living Silence")
    }

    func testJourneyNext_afterThirty() {
        XCTAssertNil(Journey.next(after: 30))
    }

    func testJourneyNext_afterThirtyOne() {
        XCTAssertNil(Journey.next(after: 31))
    }
}
