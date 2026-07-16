import SwiftUI
import UIKit

// MARK: - Gyva tyla palette

extension Color {
    static let moss       = Color(red: 0.055, green: 0.082, blue: 0.071) // #0E1512 background
    static let liquid     = Color(red: 0.373, green: 0.831, blue: 0.769) // #5FD4C4 accent
    static let liquidDeep = Color(red: 0.180, green: 0.549, blue: 0.502) // #2E8C80 depth
    static let sand       = Color(red: 0.910, green: 0.863, blue: 0.784) // #E8DCC8 text
    static let stone      = Color(red: 0.478, green: 0.545, blue: 0.522) // #7A8B85 secondary
}

// MARK: - Haptics

enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func splash()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
