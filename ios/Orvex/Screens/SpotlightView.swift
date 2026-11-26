import SwiftUI

/// البحث الشامل: الصفحات والإعدادات والنصوص والمشرفين والملفات والمنتظرين والحظر والإشعارات
struct SpotlightView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    @State private var q = ""
    @State private var results: [JSON] = []
    @State private var searching = false
    @State private var task: Task<Void, Never>?

    struct Entry { let id: String; let title: String; let icon: String; let words: String; let perms: [String] }
    static let screens: [Entry] = [
        Entry(id: "gate", title: "الاشتراكات", icon: "door.left.hand.open", words: "فتح سد اغلاق جدولة عداد مقاعد موعد", perms: ["gate", "gate.state", "gate.schedule"]),
        Entry(id: "mode", title: "وضع الموقع", icon: "power", words: "صيانة ايقاف اطفاء تشغيل", perms: ["mode.maintenance", "mode.offline"]),
        Entry(id: "plans", title: "الباقات والأسعار", icon: "tag.fill", words: "سعر عرض خصم vip دينار دولار", perms: ["plans"]),
        Entry(id: "content", title: "المحتوى والصفحات", icon: "doc.richtext.fill", words: "اسئلة faq معرض قاعة خريطة روابط seo", perms: ["content"]),
        Entry(id: "texts", title: "كل كلمة بالموقع", icon: "textformat", words: "نصوص كلمات اخفاء تعديل", perms: ["texts"]),
        Entry(id: "mood", title: "مزاج الوقت", icon: "sun.horizon.fill", words: "ترحيب الوان صبح ليل", perms: ["mood"]),
        Entry(id: "look", title: "المظهر والأقسام", icon: "paintpalette.fill", words: "اظهار اخفاء اقسام", perms: ["look"]),
        Entry(id: "geo", title: "حظر الدول وIP", icon: "shield.lefthalf.filled", words: "حظر دولة ip عنوان block", perms: ["geo"]),
        Entry(id: "advanced", title: "كل الإعدادات", icon: "slider.horizontal.3", words: "متقدم json", perms: ["advanced"]),
        Entry(id: "live", title: "هسه بالموقع", icon: "dot.radiowaves.left.and.right", words: "متصفحين مباشر", perms: ["live"]),
        Entry(id: "speed", title: "سرعة الموقع", icon: "gauge.with.dots.needle.67percent", words: "سرعة بطء lcp", perms: ["speed"]),
        Entry(id: "waitlist", title: "قائمة المنتظرين", icon: "list.bullet", words: "منتظرين تيليجرام تصدير", perms: ["waitlist.view"]),
        Entry(id: "cast", title: "أرسل التذكير", icon: "paperplane.fill", words: "ارسال تذكير جماعي رسالة", perms: ["waitlist.cast"]),
        Entry(id: "botmsgs", title: "رسائل البوت", icon: "text.bubble.fill", words: "بوت رسائل ترحيب", perms: ["notify"]),
        Entry(id: "files", title: "الملفات", icon: "folder.fill", words: "رفع ملف صور فيديو", perms: ["files.view"]),
        Entry(id: "users", title: "المشرفين", icon: "person.2.fill", words: "مشرف صلاحيات حساب", perms: ["__owner"]),
        Entry(id: "monitor", title: "المراقبة المباشرة", icon: "eye.circle.fill", words: "مراقبة اونلاين", perms: ["monitor"]),
        Entry(id: "history", title: "سجل التعديلات", icon: "clock.arrow.circlepath", words: "تراجع نسخ استعادة", perms: ["history.view"]),
        Entry(id: "log", title: "سجل النشاط", icon: "list.bullet.clipboard.fill", words: "دخول نشاط", perms: ["log.view"]),
        Entry(id: "app-updates", title: "تحديثات التطبيق", icon: "arrow.down.app.fill", words: "تحديث ipa اصدار", perms: ["app.updates"]),
        Entry(id: "app-control", title: "التحكم بالتطبيق", icon: "switch.2", words: "ايقاف التطبيق", perms: ["app.control"]),
        Entry(id: "notify-send", title: "أرسل إشعار", icon: "bell.badge.fill", words: "اشعار تنبيه", perms: ["app.notify"]),
        Entry(id: "widgets", title: "تخصيص شاشة الآيفون", icon: "widget.small", words: "ويدجت جزيرة", perms: []),
        Entry(id: "settings", title: "الإعدادات والمظهر", icon: "gearshape.fill", words: "ثيم داكن فاتح خط ايقونة قفل فيس", perms: []),
        Entry(id: "system", title: "حالة النظام", icon: "server.rack", words: "نظام بوت webhook نسخة احتياطية", perms: ["system"]),
        Entry(id: "account", title: "حسابي والأمان", icon: "person.crop.circle", words: "كلمة سر رمز اجهزة", perms: []),
        Entry(id: "inbox", title: "الإشعارات", icon: "bell.fill", words: "اشعارات", perms: []),
    ]
    func allowed(_ e: Entry) -> Bool { e.perms.isEmpty || (e.perms == ["__owner"] ? session.isOwner : session.canAny(e.perms)) }
    static func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "[\\u064B-\\u065F\\u0670\\u0640]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[أإآ]", with: "ا", options: .regularExpression).replacingOccurrences(of: "ة", with: "ه").replacingOccurrences(of: "ى", with: "ي")
    }
    var screenHits: [Entry] {
        let n = SpotlightView.norm(q)
        let list = SpotlightView.screens.filter(allowed)
        guard !n.isEmpty else { return list }
        return list.filter { SpotlightView.norm($0.title + " " + $0.words).contains(n) }
    }

    var body: some View {
        let t = prefs.theme
        List {
            if !screenHits.isEmpty {
                Section(q.isEmpty ? "روح لأي صفحة" : "الصفحات") {
                    ForEach(screenHits, id: \.id) { e in NavigationLink(value: e.id) { RowLabel(title: e.title, icon: e.icon) } }
                }
            }
            if q.count >= 2 {
                Section {
                    if searching { HStack { Spacer(); ProgressView(); Spacer() } }
                    else if results.isEmpty { Text("ماكو نتائج لـ«\(q)»").font(.ox(14)).foregroundStyle(t.mute) }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, r in resultRow(r) }
                } header: { Text("بالموقع والبيانات") }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن أي شي…")
        .oxScreen("البحث", page: "search")
        .withDestinations()
        .onChange(of: q) { _, v in
            task?.cancel()
            guard v.count >= 2 else { results = []; return }
            searching = true
            task = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                let enc = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                let r = try? await API.shared.get("/search?q=" + enc)
                if Task.isCancelled { return }
                results = r?["items"].arr ?? []
                searching = false
            }
        }
    }

    @ViewBuilder func resultRow(_ r: JSON) -> some View {
        let t = prefs.theme
        switch r["t"].str {
        case "text":
            let seg = pathFromJSON(r["seg"])
            let parent = seg.count > 1 ? Array(seg.dropLast()) : seg
            NavigationLink(value: EditRoute(path: parent, title: Labels.pathLabel(parent, store: store))) {
                RowLabel(title: r["ar"].str.isEmpty ? r["en"].str : r["ar"].str, icon: "text.quote", sub: Labels.pathLabel(seg, store: store))
            }
        case "ui":
            NavigationLink(value: "texts") { RowLabel(title: r["ar"].str, icon: "textformat", sub: "كلمة بالموقع · " + r["en"].str) }
        case "user":
            NavigationLink(value: UserRoute(id: r["id"].str)) { RowLabel(title: r["name"].str, icon: "person.fill", sub: "@" + r["username"].str) }
        case "file":
            NavigationLink(value: "files") { RowLabel(title: r["name"].str, icon: "doc.fill", sub: Fmt.bytes(r["size"].double ?? 0)) }
        case "wait":
            NavigationLink(value: "waitlist") { RowLabel(title: r["name"].str.isEmpty ? r["id"].str : r["name"].str, icon: "person.crop.circle.badge.clock", sub: r["username"].str.isEmpty ? "منتظر" : "@" + r["username"].str) }
        case "geo":
            NavigationLink(value: "geo") { RowLabel(title: "\(flag(r["cc"].str)) \(countryName(r["cc"].str))", icon: "shield.lefthalf.filled", sub: "دولة محظورة", tint: t.bad) }
        case "ip":
            NavigationLink(value: "geo") { RowLabel(title: r["ip"].str, icon: "network", sub: "عنوان محظور", tint: t.bad) }
        case "note":
            NavigationLink(value: "inbox") { RowLabel(title: r["title"].str, icon: "bell.fill", sub: r["body"].str) }
        default:
            EmptyView()
        }
    }
}
