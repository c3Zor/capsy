import SwiftUI
import SwiftData

@main
struct CapsyApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [StressDrop.self, ReleaseSession.self])
    }
}
