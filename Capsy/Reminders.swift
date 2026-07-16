import UserNotifications

/// The daily-usage engine: quiet local notifications that bring you back
/// for the minutes that matter. No streak-shaming — a whisper, not a nag.
enum Reminders {
    /// Asked once, right after onboarding.
    static func requestAndScheduleEvening() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                scheduleEvening()
            }
    }

    /// One gentle check-in every evening.
    private static func scheduleEvening() {
        let content = UNMutableNotificationContent()
        content.title = "Capsy"
        content.body = "One breath before sleep. Empty the vessel."
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
        content.body = "FULL. TIME TO POUR."
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        center.add(UNNotificationRequest(identifier: "full", content: content, trigger: trigger))
    }
}
