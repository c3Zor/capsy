import SwiftUI
import SwiftData

@main
struct CapsyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [StressDrop.self, ReleaseSession.self])
    }
}
