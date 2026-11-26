import SwiftUI
import UIKit

// MARK: - الألوان
extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// ثيمات التطبيق — كلها من هوية أورفيكس + ثيم بألوان الموقع
struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let dark: Bool
    let bg: Color, surface: Color, surface2: Color, line: Color
    let ink: Color, ink2: Color, mute: Color
    let accent: Color, onAccent: Color
    let ok: Color, warn: Color, bad: Color, info: Color

    static let all: [AppTheme] = [obsidian, graphite, midnight, steel, mist, paper, silver, iraqfit]
    static func by(_ id: String) -> AppTheme { all.first { $0.id == id } ?? obsidian }

    static let obsidian = AppTheme(id: "obsidian", name: "أوبسيديان", dark: true, bg: Color(hex: 0x0B0C0E), surface: Color(hex: 0x15171B), surface2: Color(hex: 0x1C1F24), line: Color.white.opacity(0.08), ink: .white, ink2: Color(hex: 0xC3C8D0), mute: Color(hex: 0x8A919C), accent: Color(hex: 0xB9BFC8), onAccent: Color(hex: 0x0B0C0E), ok: Color(hex: 0x3DD68C), warn: Color(hex: 0xF0B44C), bad: Color(hex: 0xF0626A), info: Color(hex: 0x7DA7F0))
    static let graphite = AppTheme(id: "graphite", name: "غرافيت", dark: true, bg: Color(hex: 0x1C1F24), surface: Color(hex: 0x23272D), surface2: Color(hex: 0x2B3037), line: Color.white.opacity(0.09), ink: .white, ink2: Color(hex: 0xD0D4DA), mute: Color(hex: 0x959CA7), accent: Color(hex: 0xEEF0F3), onAccent: Color(hex: 0x1C1F24), ok: Color(hex: 0x3DD68C), warn: Color(hex: 0xF0B44C), bad: Color(hex: 0xF0626A), info: Color(hex: 0x7DA7F0))
    static let midnight = AppTheme(id: "midnight", name: "منتصف الليل", dark: true, bg: Color(hex: 0x080B11), surface: Color(hex: 0x0F1520), surface2: Color(hex: 0x16202E), line: Color.white.opacity(0.08), ink: .white, ink2: Color(hex: 0xC5CEDC), mute: Color(hex: 0x8692A6), accent: Color(hex: 0x9DB4D6), onAccent: Color(hex: 0x080B11), ok: Color(hex: 0x45D49A), warn: Color(hex: 0xF2B652), bad: Color(hex: 0xF06A72), info: Color(hex: 0x86B0FF))
    static let steel = AppTheme(id: "steel", name: "فولاذ", dark: true, bg: Color(hex: 0x2A2F36), surface: Color(hex: 0x333941), surface2: Color(hex: 0x3B424B), line: Color.white.opacity(0.10), ink: .white, ink2: Color(hex: 0xDADDE2), mute: Color(hex: 0xA3AAB4), accent: Color(hex: 0xFFFFFF), onAccent: Color(hex: 0x2A2F36), ok: Color(hex: 0x52DE99), warn: Color(hex: 0xF4BE5E), bad: Color(hex: 0xF4747B), info: Color(hex: 0x93B6F5))
    static let mist = AppTheme(id: "mist", name: "ضباب", dark: false, bg: Color(hex: 0xEEF0F3), surface: .white, surface2: Color(hex: 0xF6F7F9), line: Color.black.opacity(0.08), ink: Color(hex: 0x0B0C0E), ink2: Color(hex: 0x2A2E35), mute: Color(hex: 0x5F6772), accent: Color(hex: 0x0B0C0E), onAccent: .white, ok: Color(hex: 0x12864C), warn: Color(hex: 0xA86A06), bad: Color(hex: 0xC42B30), info: Color(hex: 0x2563C9))
    static let paper = AppTheme(id: "paper", name: "ورقي", dark: false, bg: Color(hex: 0xF5F3EE), surface: .white, surface2: Color(hex: 0xF0EDE6), line: Color.black.opacity(0.08), ink: Color(hex: 0x16140F), ink2: Color(hex: 0x3A362E), mute: Color(hex: 0x6E695F), accent: Color(hex: 0x1C1F24), onAccent: .white, ok: Color(hex: 0x14864C), warn: Color(hex: 0xA86A06), bad: Color(hex: 0xC42B30), info: Color(hex: 0x2563C9))
    static let silver = AppTheme(id: "silver", name: "فضي", dark: false, bg: Color(hex: 0xDCDFE4), surface: Color(hex: 0xF4F5F7), surface2: Color(hex: 0xE7E9ED), line: Color.black.opacity(0.09), ink: Color(hex: 0x0B0C0E), ink2: Color(hex: 0x2A2E35), mute: Color(hex: 0x5A626D), accent: Color(hex: 0x1C1F24), onAccent: .white, ok: Color(hex: 0x12864C), warn: Color(hex: 0x9A6205), bad: Color(hex: 0xBB2A2F), info: Color(hex: 0x2459B8))
    static let iraqfit = AppTheme(id: "iraqfit", name: "عراق فيت", dark: true, bg: Color(hex: 0x0A0B0F), surface: Color(hex: 0x12141B), surface2: Color(hex: 0x1A1D26), line: Color.white.opacity(0.08), ink: Color(hex: 0xF3F4F7), ink2: Color(hex: 0xC9CCD4), mute: Color(hex: 0x8E94A3), accent: Color(hex: 0xF26A2E), onAccent: .white, ok: Color(hex: 0x2FBF71), warn: Color(hex: 0xE9A23B), bad: Color(hex: 0xE5484D), info: Color(hex: 0x5B9BFF))
}

// MARK: - تفضيلات العرض (قابلة للإرجاع للافتراضي)
struct DisplayPrefs: Codable, Equatable {
    var theme = "auto"              // auto = أوبسيديان بالليل وضباب بالنهار
    var lightTheme = "mist"
    var darkTheme = "obsidian"
    var scheme = "system"           // system | light | dark
    var textScale = 1.0             // 0.9 … 1.25
    var density = "comfortable"     // comfortable | compact
    var glass = "full"              // full | soft | off
    var haptics = true
    var westernDigits = true
    var startTab = "home"
    var tabs: [String] = ["home", "site", "stats", "telegram", "more"]
    var homeCards: [String] = ["status", "kpis", "gate", "actions", "live", "recent"]
    var hiddenHomeCards: [String] = []
    var lock = "off"                // off | instant | 1m | 5m
    var showUpdateCard = true
}

final class Prefs: ObservableObject {
    static let shared = Prefs()
    @Published var d: DisplayPrefs { didSet { persist() } }
    @Published var locked = false   // المالك منع التخصيص
    @Published var systemDark = true
    private init() {
        if let data = UserDefaults.standard.data(forKey: "orvex.prefs"), let p = try? JSONDecoder().decode(DisplayPrefs.self, from: data) { d = p } else { d = DisplayPrefs() }
    }
    private func persist() { if let data = try? JSONEncoder().encode(d) { UserDefaults.standard.set(data, forKey: "orvex.prefs") } }
    func reset() { d = DisplayPrefs() }
    /// إعدادات المالك العامة للتطبيق
    func applyAdmin(_ display: JSON, canCustomize: Bool) {
        locked = !canCustomize
        guard !canCustomize, display.isObject else { return }
        var p = DisplayPrefs()
        if let t = display["theme"].string { p.theme = t }
        if let s = display["scheme"].string { p.scheme = s }
        if let g = display["glass"].string { p.glass = g }
        if let dn = display["density"].string { p.density = dn }
        p.lock = d.lock
        d = p
    }
    var theme: AppTheme {
        switch d.theme {
        case "auto":
            let dark = d.scheme == "dark" || (d.scheme == "system" && systemDark)
            return AppTheme.by(dark ? d.darkTheme : d.lightTheme)
        default: return AppTheme.by(d.theme)
        }
    }
    var colorScheme: ColorScheme? {
        if d.theme != "auto" { return theme.dark ? .dark : .light }
        return d.scheme == "dark" ? .dark : d.scheme == "light" ? .light : nil
    }
    var pad: CGFloat { d.density == "compact" ? 12 : 16 }
    func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) { if d.haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() } }
    func notify(_ t: UINotificationFeedbackGenerator.FeedbackType) { if d.haptics { UINotificationFeedbackGenerator().notificationOccurred(t) } }
}

// MARK: - الخطوط
enum OxFont {
    static func name(_ w: Font.Weight) -> String {
        switch w { case .bold, .heavy, .black: return "ReadexPro-Bold"; case .semibold: return "ReadexPro-SemiBold"; case .medium: return "ReadexPro-Medium"; default: return "ReadexPro-Regular" }
    }
    static func sora(_ w: Font.Weight) -> String {
        switch w { case .bold, .heavy, .black: return "Sora-Bold"; case .semibold: return "Sora-SemiBold"; case .medium: return "Sora-Medium"; default: return "Sora-Regular" }
    }
}
extension Font {
    static func ox(_ size: CGFloat, _ w: Font.Weight = .regular, relativeTo s: Font.TextStyle = .body) -> Font {
        .custom(OxFont.name(w), size: size * Prefs.shared.d.textScale, relativeTo: s)
    }
    static func num(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font {
        .custom(OxFont.sora(w), size: size * Prefs.shared.d.textScale, relativeTo: .title)
    }
}

// MARK: - الزجاج (Liquid Glass بـ iOS 26 وبديل للأقدم)
struct GlassBG<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil
    var interactive = false
    @ObservedObject var prefs = Prefs.shared
    func body(content: Content) -> some View {
        if prefs.d.glass == "off" {
            content.background(prefs.theme.surface2, in: shape).overlay(shape.stroke(prefs.theme.line))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content.background(prefs.d.glass == "soft" ? AnyShapeStyle(Material.thinMaterial) : AnyShapeStyle(Material.ultraThinMaterial), in: shape)
                .overlay(shape.stroke(prefs.theme.line))
        }
    }
    @available(iOS 26.0, *)
    var glass: Glass {
        var g: Glass = .regular
        if let t = tint { g = g.tint(t.opacity(prefs.d.glass == "soft" ? 0.25 : 0.45)) }
        if interactive { g = g.interactive() }
        return g
    }
}
extension View {
    func glass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View { modifier(GlassBG(shape: shape, tint: tint, interactive: interactive)) }
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View { glass(Capsule(), tint: tint, interactive: interactive) }
    func glassRect(_ r: CGFloat = 20, tint: Color? = nil, interactive: Bool = false) -> some View { glass(RoundedRectangle(cornerRadius: r, style: .continuous), tint: tint, interactive: interactive) }
}

/// زر زجاجي متوافق
struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    @ObservedObject var prefs = Prefs.shared
    func makeBody(configuration: Configuration) -> some View {
        let t = prefs.theme
        configuration.label
            .font(.ox(15, .semibold))
            .padding(.horizontal, 18).frame(minHeight: 46)
            .foregroundStyle(prominent ? t.onAccent : t.ink)
            .background {
                if prominent { Capsule().fill(t.accent) }
            }
            .modifier(ConditionalGlass(on: !prominent))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
struct ConditionalGlass: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View { if on { content.glassCapsule(interactive: true) } else { content } }
}
extension ButtonStyle where Self == GlassButtonStyle {
    static var oxGlass: GlassButtonStyle { GlassButtonStyle() }
    static var oxProminent: GlassButtonStyle { GlassButtonStyle(prominent: true) }
}

// MARK: - تنسيق الأرقام والتواريخ
enum Fmt {
    static var digits: Locale { Prefs.shared.d.westernDigits ? Locale(identifier: "ar_IQ@numbers=latn") : Locale(identifier: "ar_IQ") }
    static func n(_ v: Double?) -> String {
        guard let v else { return "—" }
        let f = NumberFormatter(); f.locale = digits; f.numberStyle = .decimal; f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
    static func n(_ v: Int?) -> String { n(v.map(Double.init)) }
    static func n(_ j: JSON) -> String { n(j.double) }
    static func bytes(_ b: Double) -> String {
        let f = ByteCountFormatter(); f.countStyle = .file; f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: Int64(b))
    }
    static let baghdad = TimeZone(identifier: "Asia/Baghdad") ?? .current
    static func date(_ d: Date?, time: Bool = true) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.locale = digits; f.timeZone = baghdad
        f.dateStyle = .medium; f.timeStyle = time ? .short : .none
        return f.string(from: d)
    }
    static func time(_ d: Date?) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.locale = digits; f.timeZone = baghdad; f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
    static func ago(_ d: Date?) -> String {
        guard let d else { return "—" }
        let s = Int(Date().timeIntervalSince(d))
        if s < 45 { return "هسه" }
        let m = s / 60; if m < 60 { return "قبل " + (m <= 1 ? "دقيقة" : m == 2 ? "دقيقتين" : "\(n(m)) دقيقة") }
        let h = m / 60; if h < 24 { return "قبل " + (h == 1 ? "ساعة" : h == 2 ? "ساعتين" : "\(n(h)) ساعة") }
        let dd = h / 24; if dd < 30 { return "قبل " + (dd == 1 ? "يوم" : dd == 2 ? "يومين" : "\(n(dd)) يوم") }
        return date(d, time: false)
    }
    static func ms(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v >= 1000 ? String(format: "%.1f ث", v / 1000) : "\(Int(v)) م.ث"
    }
    static func dur(_ secs: Double) -> String {
        let s = Int(max(0, secs)); if s < 60 { return "\(s) ث" }
        let m = s / 60; if m < 60 { return "\(m) د" }
        return "\(m / 60) س \(m % 60) د"
    }
}

func flag(_ cc: String) -> String {
    let c = cc.uppercased()
    guard c.count == 2, c != "XX", c != "T1" else { return "🏳️" }
    return c.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map { String($0) }.joined()
}
func countryName(_ cc: String) -> String {
    if cc == "XX" || cc.isEmpty { return "غير معروف" }
    return Locale(identifier: "ar").localizedString(forRegionCode: cc) ?? cc
}
let cityAR: [String: String] = ["Erbil": "أربيل", "Arbil": "أربيل", "Baghdad": "بغداد", "Basra": "البصرة", "Basrah": "البصرة", "Mosul": "الموصل", "Sulaymaniyah": "السليمانية", "As Sulaymaniyah": "السليمانية", "Kirkuk": "كركوك", "Najaf": "النجف", "An Najaf": "النجف", "Karbala": "كربلاء", "Duhok": "دهوك", "Dahuk": "دهوك", "Hillah": "الحلة", "Al Hillah": "الحلة", "Nasiriyah": "الناصرية", "An Nasiriyah": "الناصرية", "Ramadi": "الرمادي", "Fallujah": "الفلوجة", "Kut": "الكوت", "Al Kut": "الكوت", "Amarah": "العمارة", "Diwaniyah": "الديوانية", "Samawah": "السماوة", "Baqubah": "بعقوبة", "Tikrit": "تكريت", "Samarra": "سامراء", "Zakho": "زاخو", "Halabja": "حلبجة", "Kufa": "الكوفة", "Soran": "سوران", "Dubai": "دبي", "Abu Dhabi": "أبوظبي", "Istanbul": "إسطنبول", "Ankara": "أنقرة", "London": "لندن", "Stockholm": "ستوكهولم", "Berlin": "برلين", "Amman": "عمّان", "Riyadh": "الرياض", "Kuwait City": "الكويت", "Tehran": "طهران", "Beirut": "بيروت", "Cairo": "القاهرة", "Damascus": "دمشق", "Doha": "الدوحة", "Detroit": "ديترويت"]
func cityName(_ c: String) -> String { cityAR[c] ?? c }
