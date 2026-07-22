import HealthKit

/// The quiet body-signal bridge: reads a whisper of HRV, writes a mindful
/// minute when you pour. Never required, never loud — if HealthKit isn't
/// available or permission isn't granted, everything here just does nothing.
enum Health {
    /// True on real devices with Health data; false on machines that don't have it.
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let store = HKHealthStore()

    /// Asks once for the two permissions Capsy needs: writing mindful
    /// sessions (your ritual) and reading HRV (the body-signal line).
    /// Fire-and-forget — the caller doesn't wait, and this never crashes
    /// if HealthKit is unavailable or the user says no.
    static func requestAuthorization() {
        guard isAvailable,
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession),
              let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        else { return }

        store.requestAuthorization(toShare: [mindful], read: [hrv]) { _, _ in
            // Fire-and-forget: the sheet did its job either way.
        }
    }

    /// Logs the ritual you just finished as a mindful session in Health.
    /// Silent on failure — an unavailable store or a "no" from the user
    /// should never interrupt the pour.
    static func logMindfulSession(start: Date, end: Date) {
        guard isAvailable,
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        else { return }

        let sample = HKCategorySample(type: mindful, value: 0, start: start, end: end)
        store.save(sample) { _, _ in
            // Silent: whether it saved or not, the ritual already happened.
        }
    }

    /// Reads the most recent HRV (SDNN) sample from the last 24 hours, in
    /// milliseconds. Calls back on the main thread with nil when HealthKit
    /// is unavailable, unauthorized, or there's simply no recent sample.
    static func fetchLatestHRV(_ completion: @escaping (Double?) -> Void) {
        guard isAvailable,
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let since = Calendar.current.date(byAdding: .hour, value: -24, to: .now) ?? .now
        let window = HKQuery.predicateForSamples(withStart: since, end: .now, options: .strictStartDate)
        let mostRecentFirst = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: window,
            limit: 1,
            sortDescriptors: [mostRecentFirst]
        ) { _, samples, _ in
            let ms = (samples?.first as? HKQuantitySample)?
                .quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            DispatchQueue.main.async { completion(ms) }
        }
        store.execute(query)
    }

    /// Turns a raw HRV reading into the one-line body signal shown on
    /// Home. Thresholds are a gentle read, not a diagnosis. Nil in, nil
    /// out — no line is shown when there's nothing to say.
    static func bodySignalLine(hrvMs: Double?) -> String? {
        guard let hrvMs else { return nil }
        switch hrvMs {
        case ..<35:
            return "BODY SIGNAL: TENSE. MAYBE A BREATH?"
        case 35..<65:
            return "BODY SIGNAL: STEADY."
        default:
            return "BODY SIGNAL: RESTED."
        }
    }
}
