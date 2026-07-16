import SwiftUI
import SwiftData

@main
struct CapsyApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("themeMode") private var themeMode = "auto"

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            // Diena/naktis pagal paros laiką (21–7 — naktis) arba rankinį pasirinkimą.
            .preferredColorScheme(DayNight.isNight(themeMode) ? .dark : .light)
        }
        .modelContainer(for: [StressDrop.self, ReleaseSession.self])
    }
}
