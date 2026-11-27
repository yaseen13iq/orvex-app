import SwiftUI

/// تنسيق الأرقام والتواريخ والمدد بالعربية الفصحى
enum Fmt {
    static var locale: Locale { Prefs.useWesternDigits ? Locale(identifier: "ar_IQ@numbers=latn") : Locale(identifier: "ar_IQ") }
    static let baghdad = TimeZone(identifier: "Asia/Baghdad") ?? .current

    static func n(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        let f = NumberFormatter(); f.locale = locale; f.numberStyle = .decimal; f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
    static func n(_ v: Int?) -> String { n(v.map(Double.init)) }
    static func n(_ j: JSON) -> String { n(j.double) }
    static func money(_ v: Double?, _ cur: String = "IQD") -> String {
        guard let v else { return "—" }
        return cur == "USD" ? "$" + n(v) : n(v) + " د.ع"
    }
    static func percent(_ v: Double) -> String { n((v * 100).rounded()) + "٪" }
    static func bytes(_ b: Double) -> String {
        if b < 1024 { return n(b) + " بايت" }
        if b < 1024 * 1024 { return n((b / 1024 * 10).rounded() / 10) + " ك.ب" }
        if b < 1024 * 1024 * 1024 { return n((b / 1024 / 1024 * 10).rounded() / 10) + " م.ب" }
        return n((b / 1024 / 1024 / 1024 * 100).rounded() / 100) + " غ.ب"
    }
    static func date(_ d: Date?, time: Bool = true) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.locale = locale; f.timeZone = baghdad
        f.dateFormat = time ? "EEEE d MMMM، h:mm a" : "EEEE d MMMM yyyy"
        return f.string(from: d)
    }
    static func shortDate(_ d: Date?) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.locale = locale; f.timeZone = baghdad; f.dateFormat = "d MMM"
        return f.string(from: d)
    }
    static func time(_ d: Date?) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.locale = locale; f.timeZone = baghdad; f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
    /// «قبل 5 دقائق» بصيغة فصيحة
    static func ago(_ d: Date?) -> String {
        guard let d else { return "—" }
        let s = Int(Date().timeIntervalSince(d))
        if s < 0 { return "بعد " + span(-s) }
        if s < 45 { return "الآن" }
        if s >= 30 * 86400 { return date(d, time: false) }
        return "قبل " + span(s)
    }
    /// مدة مقروءة: «3 دقائق»، «ساعتان»، «يوم واحد»
    static func span(_ secs: Int) -> String {
        let m = secs / 60, h = m / 60, d = h / 24
        if d >= 1 { return plural(d, "يوم", "يومين", "أيام", "يومًا") }
        if h >= 1 { return plural(h, "ساعة", "ساعتين", "ساعات", "ساعة") }
        return plural(max(1, m), "دقيقة", "دقيقتين", "دقائق", "دقيقة")
    }
    static func plural(_ v: Int, _ one: String, _ two: String, _ few: String, _ many: String) -> String {
        if v == 1 { return one }
        if v == 2 { return two }
        if v >= 3 && v <= 10 { return n(v) + " " + few }
        return n(v) + " " + many
    }
    static func dur(_ secs: Double) -> String {
        let s = Int(max(0, secs))
        if s < 60 { return n(s) + " ث" }
        let m = s / 60
        if m < 60 { return n(m) + " د" }
        return n(m / 60) + " س " + n(m % 60) + " د"
    }
    static func ms(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v >= 1000 ? n((v / 100).rounded() / 10) + " ث" : n(v.rounded()) + " م.ث"
    }
}

func flag(_ cc: String) -> String {
    let c = cc.uppercased()
    guard c.count == 2, c != "XX", c != "T1" else { return "🏳️" }
    return c.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map { String($0) }.joined()
}
func countryName(_ cc: String) -> String {
    if cc == "XX" || cc.isEmpty { return "غير معروفة" }
    return Locale(identifier: "ar").localizedString(forRegionCode: cc) ?? cc
}
private let cityAR: [String: String] = ["Erbil": "أربيل", "Arbil": "أربيل", "Baghdad": "بغداد", "Basra": "البصرة", "Basrah": "البصرة", "Mosul": "الموصل", "Sulaymaniyah": "السليمانية", "As Sulaymaniyah": "السليمانية", "Kirkuk": "كركوك", "Najaf": "النجف", "An Najaf": "النجف", "Karbala": "كربلاء", "Duhok": "دهوك", "Dahuk": "دهوك", "Hillah": "الحلة", "Al Hillah": "الحلة", "Nasiriyah": "الناصرية", "An Nasiriyah": "الناصرية", "Ramadi": "الرمادي", "Fallujah": "الفلوجة", "Kut": "الكوت", "Al Kut": "الكوت", "Amarah": "العمارة", "Diwaniyah": "الديوانية", "Samawah": "السماوة", "Baqubah": "بعقوبة", "Tikrit": "تكريت", "Samarra": "سامراء", "Zakho": "زاخو", "Halabja": "حلبجة", "Kufa": "الكوفة", "Soran": "سوران", "Dubai": "دبي", "Abu Dhabi": "أبوظبي", "Istanbul": "إسطنبول", "Ankara": "أنقرة", "London": "لندن", "Stockholm": "ستوكهولم", "Berlin": "برلين", "Amman": "عمّان", "Riyadh": "الرياض", "Kuwait City": "الكويت", "Tehran": "طهران", "Beirut": "بيروت", "Cairo": "القاهرة", "Damascus": "دمشق", "Doha": "الدوحة"]
func cityName(_ c: String) -> String { c.isEmpty ? "غير معروفة" : (cityAR[c] ?? c) }

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

extension JSON {
    /// أزواج (مفتاح، عدد) مرتبة تنازليًا
    var counts: [(key: String, n: Double)] { (object?.pairs ?? []).map { (key: $0.0, n: $0.1.double ?? 0) }.sorted { $0.n > $1.n } }
}

/// أسماء عربية لمصادر الزيارات والأجهزة والأنظمة
enum Names {
    static let sources: [String: String] = ["ig": "إنستغرام", "instagram": "إنستغرام", "direct": "دخول مباشر", "google": "بحث Google", "search": "محركات البحث", "fb": "فيسبوك", "facebook": "فيسبوك", "tiktok": "تيك توك", "tg": "تيليجرام", "telegram": "تيليجرام", "wa": "واتساب", "whatsapp": "واتساب", "snap": "سناب شات", "x": "إكس (تويتر)", "twitter": "إكس (تويتر)", "yt": "يوتيوب", "youtube": "يوتيوب", "other": "مصادر أخرى", "ref": "مواقع أخرى"]
    static let devices: [String: String] = ["mob": "هاتف", "mobile": "هاتف", "tab": "جهاز لوحي", "tablet": "جهاز لوحي", "desk": "حاسوب", "desktop": "حاسوب", "bot": "روبوت"]
    static let os: [String: String] = ["ios": "iOS", "android": "Android", "win": "Windows", "windows": "Windows", "mac": "macOS", "macos": "macOS", "linux": "Linux", "other": "أخرى"]
    static let browsers: [String: String] = ["ig": "متصفح إنستغرام", "safari": "Safari", "chrome": "Chrome", "firefox": "Firefox", "edge": "Edge", "samsung": "Samsung", "fb": "متصفح فيسبوك", "tiktok": "متصفح تيك توك", "other": "أخرى"]
    static let langs: [String: String] = ["ar": "العربية", "en": "الإنجليزية", "ku": "الكردية", "tr": "التركية", "fa": "الفارسية", "other": "أخرى"]
    static let pages: [String: String] = ["/": "الصفحة الرئيسية", "home": "الصفحة الرئيسية", "/about": "من أنا", "/terms": "الشروط", "/privacy": "الخصوصية", "/results": "معرض النتائج", "/train": "وضع التدريب", "train": "وضع التدريب"]
    static let events: [String: String] = ["cta": "نقرات «اشترك»", "rem": "نقرات «ذكّرني»", "ig": "نقرات إنستغرام", "plan": "فتح تفاصيل باقة", "faq": "فتح سؤال", "map": "فتح الخريطة", "train": "دخول وضع التدريب", "share": "مشاركة", "theme": "تبديل المظهر", "lang": "تبديل اللغة", "dev": "نقرات بطاقة المطوّر"]
}
