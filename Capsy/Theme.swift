import SwiftUI
import UIKit

// MARK: - Gyva tyla V4.5 palette (from the design book)
//
// Day:   sand #EDE4D6 · earth #2B2620 · smoke #8A7E6E · coral #E8865C · linen #D9CBB6
// Naktis: #191511 · #EDE4D6 · #9C8F7D · #F0A06E · #211B15
// Colors are dynamic — they switch with the ColorScheme (see CapsyApp.themeScheme).

private func dyn(_ day: UInt32, _ night: UInt32) -> Color {
    func ui(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(night) : ui(day) })
}

extension Color {
    static let bg      = dyn(0xEDE4D6, 0x191511) // background — sand / night
    static let ink     = dyn(0x2B2620, 0xEDE4D6) // text — earth
    static let sub     = dyn(0x8A7E6E, 0x9C8F7D) // secondary — smoke
    static let acc     = dyn(0xE8865C, 0xF0A06E) // akcentas — koralas (skystis, mygtukai)
    static let accDeep = dyn(0xC4633C, 0xC97A4E) // coral depth (bottom of the liquid)
    static let lino    = dyn(0xD9CBB6, 0x211B15) // surfaces — linen
}

// MARK: - Typography (design book: compressed poster caps + mono digits)

extension Font {
    /// Headlines — compressed poster ALL CAPS.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }
    /// Digits and labels — mono, tabular.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Motion (design book: spring 90/16 — soft earthy gravity)

extension Animation {
    static let earth = Animation.spring(response: 0.66, dampingFraction: 0.84)
}

// MARK: - Day / night (design book: night 21:00–7:00, manual override)

enum DayNight {
    /// mode: "auto" | "day" | "night"
    static func isNight(_ mode: String) -> Bool {
        if mode == "night" { return true }
        if mode == "day" { return false }
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 21 || hour < 7
    }
}

// MARK: - Haptics (a living pulse under the finger)

enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func splash()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
