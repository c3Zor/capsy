import UserNotifications
import Foundation

/// The daily-usage engine: quiet local notifications that bring you back
/// for the minutes that matter. No streak-shaming — a whisper, not a nag.
/// Capsy speaks, never nags.
enum Reminders {

    // MARK: - Copy (rotates by day of year, stable per calendar day)

    private static let morningLines: [String] = [
        "Good morning. How heavy is today?",
        "I kept the garden while you slept.",
        "A new vessel. Fill it gently.",
        "The morning is quiet. So is this.",
        "Awake now. No rush to begin.",
        "Light is back. So are you.",
        "Today starts empty. That is good.",
    ]

    private static let eveningLines: [String] = [
        "One breath before sleep.",
        "Today can end lighter than it began.",
        "Empty the vessel. Rest the mind.",
        "Whatever today was, it is nearly over.",
        "A calm close, if you have a moment.",
        "The day softens now. Come sit with it.",
        "Pour it out before you lie down.",
    ]

    private static let fullLines: [String] = [
        "FULL. TIME TO POUR.",
        "The vessel is brimming. Let it go.",
        "Nothing more fits. Pour, when ready.",
    ]

    /// Picks a stable-per-day index into `lines` using the day of year.
    private static func rotatingIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return dayOfYear % count
    }

    // MARK: - Public API

    /// Asked once, right after onboarding: requests permission, then
    /// schedules both the morning and evening check-ins.
    static func requestAndScheduleEvening() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                scheduleMorning()
                scheduleEvening()
            }
    }

    /// Re-registers morning + evening notifications under their stable
    /// identifiers, rotating the copy for the day. Safe to call on every
    /// app launch — a no-op if notifications were never authorized, and
    /// replaces (rather than duplicates) any pending request with the
    /// same identifier.
    static func refreshAll() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            scheduleMorning()
            scheduleEvening()
        }
    }

    /// One gentle greeting every morning.
    static func scheduleMorning() {
        let content = UNMutableNotificationContent()
        content.title = "Capsy"
        content.body = morningLines[rotatingIndex(count: morningLines.count)]
        content.sound = nil
        var time = DateComponents()
        time.hour = 9
        time.minute = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "morning", content: content, trigger: trigger))
    }

    /// One gentle check-in every evening.
    private static func scheduleEvening() {
        let content = UNMutableNotificationContent()
        content.title = "Capsy"
        content.body = eveningLines[rotatingIndex(count: eveningLines.count)]
        content.sound = nil
        var time = DateComponents()
        time.hour = 20
        time.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "evening", content: content, trigger: trigger))
    }

    /// When the vessel fills up, a single nudge 30 minutes later —
    /// and it is cancelled the moment you pour.
    static func nudgeWhenFull(fraction: Double) {
        let center = UNUserNotificationCenter.current()
        guard fraction >= 1 else {
            center.removePendingNotificationRequests(withIdentifiers: ["full"])
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Capsy"
        content.body = fullLines[rotatingIndex(count: fullLines.count)]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        center.add(UNNotificationRequest(identifier: "full", content: content, trigger: trigger))
    }
}
