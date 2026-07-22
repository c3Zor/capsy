import SwiftUI
import SwiftData

@main
struct CapsyApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("themeMode") private var themeMode = "auto"

    init() {
        // CI screenshot mode: skip onboarding, pick theme, seed the vessel.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--demo") {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
            UserDefaults.standard.set(args.contains("--night") ? "night" : "day",
                                      forKey: "themeMode")
            // Deterministic screenshots: the matrix reuses one simulator, so
            // always reset to the exact seed instead of keeping prior data.
            let context = AppDatabase.container.mainContext
            for drop in (try? context.fetch(FetchDescriptor<StressDrop>())) ?? [] {
                context.delete(drop)
            }
            // --fill-full seeds to capacity (4×6 = 24); plain --demo ~50 %.
            let intensities = args.contains("--fill-full") ? [3, 3, 3, 3] : [1, 2, 3]
            for i in intensities { context.insert(StressDrop(intensity: i, note: "")) }
            try? context.save()
        }
    }

    /// CI screenshot mode: "--screen shop|habits|journey|ritual" shows that
    /// screen as root so the matrix can photograph every part of the app.
    private var demoScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch demoScreen {
                case "ritual":  ReleaseView()
                case "shop":    NavigationStack { ShopView() }
                case "habits":  NavigationStack { HabitsView() }
                case "journey": NavigationStack { JourneyView() }
                case "paywall": PaywallView()
                default:
                    if hasOnboarded {
                        HomeView()
                    } else {
                        OnboardingView()
                    }
                }
            }
            // Day/night by time of day (21:00–7:00 is night) or manual override.
            .preferredColorScheme(DayNight.isNight(themeMode) ? .dark : .light)
        }
        .modelContainer(AppDatabase.container)
    }
}
