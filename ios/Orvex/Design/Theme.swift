import SwiftUI

// MARK: - تفضيلات العرض
@MainActor
final class Prefs: ObservableObject {
    static let shared = Prefs()
    /// system | light | dark
    @Published var appearance: String { didSet { save() } }
    @Published var westernDigits: Bool { didSet { save() } }
    @Published var haptics: Bool { didSet { save() } }
    /// هل فرض المسؤول مظهرًا معيّنًا على هذا المشرف؟
    @Published private(set) var locked = false
    private var adminAppearance: String? = nil

    init() {
        let d = UserDefaults.standard
        appearance = d.string(forKey: "orvex.appearance") ?? "system"
        westernDigits = d.object(forKey: "orvex.westernDigits") as? Bool ?? true
        haptics = d.object(forKey: "orvex.haptics") as? Bool ?? true
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(appearance, forKey: "orvex.appearance")
        d.set(westernDigits, forKey: "orvex.westernDigits")
        d.set(haptics, forKey: "orvex.haptics")
    }
    var effectiveAppearance: String { locked ? (adminAppearance ?? "system") : appearance }
    var colorScheme: ColorScheme? {
        switch effectiveAppearance { case "light": return .light; case "dark": return .dark; default: return nil }
    }
    func applyAdmin(_ display: JSON, canCustomize: Bool) {
        let s = display["scheme"].string
        if !canCustomize, let s, s != "system", !s.isEmpty { locked = true; adminAppearance = s }
        else { locked = false; adminAppearance = nil }
    }
    func reset() { appearance = "system"; westernDigits = true; haptics = true }
}

// MARK: - الألوان (تتبدّل تلقائيًا بين الفاتح والداكن)
extension Color {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}
enum C {
    static let bg = Color.dyn(0xF2F3F5, 0x0B0C0E)
    static let card = Color.dyn(0xFFFFFF, 0x17191D)
    static let card2 = Color.dyn(0xF6F7F9, 0x1F2227)
    static let ink = Color.dyn(0x0B0C0E, 0xF2F3F5)
    static let ink2 = Color.dyn(0x3A3F47, 0xC9CDD3)
    static let mute = Color.dyn(0x7A818C, 0x8A919C)
    static let line = Color.dyn(0xE6E8EC, 0x2A2E35)
    static let fill = Color.dyn(0xF2F3F5, 0x23262C)
    static let ok = Color.dyn(0x1F9D57, 0x3DD68C)
    static let warn = Color.dyn(0xC27A0E, 0xF0B44C)
    static let bad = Color.dyn(0xD33A3A, 0xF0626A)
    static let info = Color.dyn(0x2F6FE0, 0x7DA6F0)
    /// لون الأزرار الرئيسية: أسود في الفاتح وأبيض في الداكن
    static let primary = Color.dyn(0x0B0C0E, 0xF2F3F5)
    static let onPrimary = Color.dyn(0xFFFFFF, 0x0B0C0E)
    /// خلفية البطاقة الداكنة في الرئيسية
    static let hero = Color.dyn(0x0B0C0E, 0x1F2227)

    static func tone(_ t: String?) -> Color {
        switch t { case "ok": return ok; case "warn": return warn; case "bad": return bad; case "info": return info; default: return mute }
    }
    static func toneBG(_ t: String?) -> Color { tone(t).opacity(0.13) }

    /// ألوان مربعات الأيقونات
    static let tiles: [String: Color] = [
        "green": Color(hex: 0x1F9D57), "blue": Color(hex: 0x2F6FE0), "amber": Color(hex: 0xC27A0E), "indigo": Color(hex: 0x5B5FC7),
        "teal": Color(hex: 0x0E8A8A), "pink": Color(hex: 0xC2456B), "graphite": Color(hex: 0x3A3F47), "steel": Color(hex: 0x5F6772),
        "red": Color(hex: 0xD33A3A), "orange": Color(hex: 0xE2733C), "purple": Color(hex: 0x8A4FC7),
    ]
}

// MARK: - الخطوط
extension Font {
    /// خط Readex Pro العربي، ويتكيّف مع حجم الخط في الجهاز
    static func ox(_ size: CGFloat, _ w: Font.Weight = .regular, relativeTo s: Font.TextStyle = .body) -> Font {
        let name: String
        switch w { case .bold, .heavy, .black: name = "ReadexPro-Bold"; case .semibold: name = "ReadexPro-SemiBold"; case .medium: name = "ReadexPro-Medium"; default: name = "ReadexPro-Regular" }
        return .custom(name, size: size, relativeTo: s)
    }
    /// خط الأرقام الكبيرة
    static func num(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font {
        let name: String
        switch w { case .bold, .heavy, .black: name = "Sora-Bold"; case .semibold: name = "Sora-SemiBold"; case .medium: name = "Sora-Medium"; default: name = "Sora-Regular" }
        return .custom(name, size: size, relativeTo: .title)
    }
}
