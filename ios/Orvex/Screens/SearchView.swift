import SwiftUI

/// البحث في صفحات التطبيق ومحتوى الموقع
struct SearchView: View {
    @EnvironmentObject var session: Session
    @State private var q = ""
    @State private var results: [JSON] = []
    @State private var searching = false
    @State private var task: Task<Void, Never>?

    struct Entry { let route: AnyHashableRoute; let title: String; let icon: String; let words: String; let perms: [String] }
    static let entries: [Entry] = [
        Entry(route: .screen("gate"), title: "حالة الاشتراكات", icon: "door.left.hand.open", words: "فتح اغلاق مغلقة مفتوحة قريبا اكتمل", perms: ["gate", "gate.state"]),
        Entry(route: .screen("schedule"), title: "جدولة الفتح والإغلاق", icon: "calendar.badge.clock", words: "موعد تلقائي جدولة", perms: ["gate.schedule"]),
        Entry(route: .screen("plans"), title: "الباقات والأسعار", icon: "tag.fill", words: "سعر باقة عرض خصم دينار دولار", perms: ["plans"]),
        Entry(route: .form("vip", P("vip")), title: "باقة VIP", icon: "crown.fill", words: "vip نخبة شخصي قاعة", perms: ["plans"]),
        Entry(route: .screen("pricing"), title: "العملة وشريط الاشتراك", icon: "dollarsign.circle.fill", words: "عملة صرف شريط", perms: ["plans"]),
        Entry(route: .screen("sections"), title: "أقسام الصفحة الرئيسية", icon: "square.stack.3d.up.fill", words: "قسم اخفاء اظهار اهداف خطوات مقارنة ارقام", perms: ["content", "look"]),
        Entry(route: .screen("faq"), title: "الأسئلة الشائعة", icon: "questionmark.bubble.fill", words: "سؤال جواب", perms: ["content"]),
        Entry(route: .screen("pages"), title: "الصفحات الإضافية", icon: "doc.text.fill", words: "من انا شروط خصوصية", perms: ["content"]),
        Entry(route: .screen("links"), title: "الروابط والتواصل", icon: "link", words: "انستغرام واتساب رابط بريد", perms: ["content"]),
        Entry(route: .screen("texts"), title: "نصوص الموقع", icon: "character.cursor.ibeam", words: "كلمة عبارة نص اخفاء", perms: ["texts"]),
        Entry(route: .screen("look"), title: "المظهر الافتراضي للزوار", icon: "paintpalette.fill", words: "داكن فاتح لون", perms: ["look"]),
        Entry(route: .screen("mood"), title: "الترحيب حسب الوقت", icon: "sun.horizon.fill", words: "ترحيب صباح ليل الوان", perms: ["mood"]),
        Entry(route: .screen("seo"), title: "محركات البحث والحقوق", icon: "magnifyingglass", words: "google جوجل عنوان حقوق", perms: ["content"]),
        Entry(route: .screen("mode"), title: "وضع الموقع", icon: "power", words: "صيانة ايقاف تشغيل", perms: ["mode.maintenance", "mode.offline"]),
        Entry(route: .screen("geo"), title: "حظر الدول والعناوين", icon: "shield.lefthalf.filled", words: "حظر دولة ip عنوان", perms: ["geo"]),
        Entry(route: .screen("live"), title: "المتصفحون الآن", icon: "dot.radiowaves.left.and.right", words: "مباشر الان", perms: ["live"]),
        Entry(route: .screen("speed"), title: "سرعة الموقع", icon: "gauge.with.dots.needle.67percent", words: "سرعة بطء", perms: ["speed"]),
        Entry(route: .screen("waitlist"), title: "قائمة المنتظرين", icon: "person.3.fill", words: "منتظرين تيليجرام تصدير", perms: ["waitlist.view"]),
        Entry(route: .screen("cast"), title: "إرسال تذكير", icon: "paperplane.fill", words: "ارسال تذكير رسالة جماعية", perms: ["waitlist.cast"]),
        Entry(route: .screen("bot"), title: "رسائل بوت التذكير", icon: "text.bubble.fill", words: "بوت رسالة ترحيب", perms: ["notify"]),
        Entry(route: .screen("users"), title: "المشرفون والصلاحيات", icon: "person.2.badge.gearshape.fill", words: "مشرف صلاحية حساب", perms: ["__owner"]),
        Entry(route: .screen("history"), title: "سجل التعديلات", icon: "clock.arrow.circlepath", words: "تراجع نسخة استعادة", perms: ["history.view"]),
        Entry(route: .screen("log"), title: "سجل الدخول والنشاط", icon: "list.bullet.rectangle.portrait.fill", words: "دخول نشاط", perms: ["log.view"]),
        Entry(route: .screen("files"), title: "الملفات", icon: "folder.fill", words: "رفع صورة ملف فيديو", perms: ["files.view"]),
        Entry(route: .screen("app-updates"), title: "تحديثات التطبيق", icon: "arrow.down.app.fill", words: "تحديث ipa اصدار", perms: ["app.updates"]),
        Entry(route: .screen("system"), title: "حالة النظام", icon: "server.rack", words: "نظام بوت نسخة احتياطية cron", perms: ["system"]),
        Entry(route: .screen("settings"), title: "الإعدادات", icon: "gearshape.fill", words: "مظهر داكن كلمة مرور ايقونة", perms: []),
    ]
    func allowed(_ e: Entry) -> Bool { e.perms.isEmpty || (e.perms == ["__owner"] ? session.isOwner : session.canAny(e.perms)) }
    var screens: [Entry] {
        let n = TextsView.norm(q)
        return SearchView.entries.filter(allowed).filter { n.isEmpty || TextsView.norm($0.title + " " + $0.words).contains(n) }
    }

    var body: some View {
        Page(title: "البحث", intro: q.isEmpty ? "ابحث عن صفحة في التطبيق، أو عن أي نص في الموقع." : nil, id: "search") {
            if !screens.isEmpty {
                SectionTitle(q.isEmpty ? "الصفحات" : "الصفحات المطابقة")
                Card { ForEach(screens.indices, id: \.self) { i in NavRow(value: screens[i].route, title: screens[i].title, icon: screens[i].icon, color: "graphite") } }
            }
            if q.count >= 2 {
                SectionTitle("في محتوى الموقع")
                Card {
                    if searching { ProgressView().frame(maxWidth: .infinity).padding() }
                    else if results.isEmpty { Text("لا توجد نتائج لـ«\(q)».").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                    ForEach(Array(results.prefix(40).enumerated()), id: \.offset) { _, r in row(r) }
                }
            }
        }
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث…")
        .onChange(of: q) { _, v in
            task?.cancel()
            guard v.count >= 2 else { results = []; return }
            searching = true
            task = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                let r = try? await API.shared.get("/search?q=" + (v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v))
                if Task.isCancelled { return }
                results = r?["items"].arr ?? []; searching = false
            }
        }
    }

    @ViewBuilder func row(_ r: JSON) -> some View {
        switch r["t"].str {
        case "text":
            let p = pathFromJSON(r["seg"])
            NavRow(value: SearchView.route(for: p), title: r["ar"].str.isEmpty ? r["en"].str : r["ar"].str, sub: FieldNames.label(p), icon: "text.quote", color: "indigo")
        case "ui": NavRow(value: AnyHashableRoute.screen("texts"), title: r["ar"].str, sub: "عبارة في الموقع", icon: "character.cursor.ibeam", color: "purple")
        case "user": NavRow(value: UserRoute(id: r["id"].str), title: r["name"].str, sub: "@" + r["username"].str, icon: "person.fill", color: "graphite")
        case "file": NavRow(value: AnyHashableRoute.screen("files"), title: r["name"].str, sub: Fmt.bytes(r["size"].double ?? 0), icon: "doc.fill", color: "teal")
        case "wait": NavRow(value: AnyHashableRoute.screen("waitlist"), title: r["name"].str.isEmpty ? r["id"].str : r["name"].str, sub: "في قائمة المنتظرين", icon: "person.crop.circle.badge.clock", color: "blue")
        case "geo": NavRow(value: AnyHashableRoute.screen("geo"), title: flag(r["cc"].str) + " " + countryName(r["cc"].str), sub: "دولة محظورة", icon: "shield.lefthalf.filled", color: "red")
        case "ip": NavRow(value: AnyHashableRoute.screen("geo"), title: r["ip"].str, sub: "عنوان محظور", icon: "network", color: "red")
        case "note": NavRow(value: AnyHashableRoute.screen("inbox"), title: r["title"].str, sub: r["body"].str, icon: "bell.fill", color: "red")
        default: EmptyView()
        }
    }

    /// يحدّد صفحة التحرير المناسبة لمسار في الإعدادات
    static func route(for p: [Seg]) -> AnyHashableRoute {
        let k = p.first?.keyName ?? ""
        if k == "gate" { return .screen(p.dropFirst().first?.keyName == "text" ? "gate" : "gate") }
        if k == "texts" { return .screen("texts") }
        let pt = FieldNames.pattern(p)
        var best: (Int, String, Int)? = nil
        for (b, id) in FieldNames.bases where !b.isEmpty {
            if pt == b || pt.hasPrefix(b + ".") {
                let n = b.split(separator: ".").count
                if best == nil || n > best!.0 { best = (n, id, n) }
            }
        }
        if let b = best { return .form(b.1, Array(p.prefix(b.2))) }
        let rootForms = ["brand": "intro", "cta": "intro", "currency": "pricing", "bar": "pricing", "links": "links", "seo": "seo", "legal": "seo", "ui": "look", "mood": "mood"]
        if let f = rootForms[k] { return .form(f, []) }
        return .screen("sections")
    }
}
