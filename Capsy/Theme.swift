import SwiftUI
import UIKit

// MARK: - Gyva tyla V4.5 palette (iš design book)
//
// Diena:  smėlis #EDE4D6 · žemė #2B2620 · dūmas #8A7E6E · koralas #E8865C · lino #D9CBB6
// Naktis: #191511 · #EDE4D6 · #9C8F7D · #F0A06E · #211B15
// Spalvos dinaminės — persijungia kartu su ColorScheme (žr. CapsyApp.themeScheme).

private func dyn(_ day: UInt32, _ night: UInt32) -> Color {
    func ui(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(night) : ui(day) })
}

extension Color {
    static let bg      = dyn(0xEDE4D6, 0x191511) // fonas — smėlis / naktis
    static let ink     = dyn(0x2B2620, 0xEDE4D6) // tekstas — žemė
    static let sub     = dyn(0x8A7E6E, 0x9C8F7D) // antraeiliai — dūmas
    static let acc     = dyn(0xE8865C, 0xF0A06E) // akcentas — koralas (skystis, mygtukai)
    static let accDeep = dyn(0xC4633C, 0xC97A4E) // koralo gylis (skysčio dugnas)
    static let lino    = dyn(0xD9CBB6, 0x211B15) // paviršiai — lino
}

// MARK: - Tipografija (design book: suspausta plakatinė + mono skaičiai)

extension Font {
    /// Antraštės — suspaustos plakatinės ALL CAPS.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }
    /// Skaičiai ir etiketės — mono, tabuliuoti.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Judesys (design book: spring 90/16 — minkšta žemiška gravitacija)

extension Animation {
    static let earth = Animation.spring(response: 0.66, dampingFraction: 0.84)
}

// MARK: - Diena / naktis (design book: naktis 21–7 val., rankinis perjungimas)

enum DayNight {
    /// mode: "auto" | "day" | "night"
    static func isNight(_ mode: String) -> Bool {
        if mode == "night" { return true }
        if mode == "day" { return false }
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 21 || hour < 7
    }
}

// MARK: - Haptika (gyvas pulsas po pirštu)

enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func splash()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
