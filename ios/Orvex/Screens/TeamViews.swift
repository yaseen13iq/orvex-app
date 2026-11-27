import SwiftUI

/// الصلاحيات كما تظهر في التطبيق
enum PermCatalog {
    struct Perm { let k: String; let n: String; let s: Bool }
    static let groups: [(String, [Perm])] = [
        ("المشاهدة", [
            Perm(k: "stats", n: "الإحصاءات والزوار", s: false), Perm(k: "live", n: "المتصفحون الآن", s: false), Perm(k: "speed", n: "سرعة الموقع", s: false),
            Perm(k: "waitlist.view", n: "قائمة المنتظرين", s: false), Perm(k: "history.view", n: "سجل التعديلات", s: false), Perm(k: "log.view", n: "سجل الدخول والنشاط", s: false),
            Perm(k: "monitor", n: "معرفة المتصلين من الفريق", s: false), Perm(k: "files.view", n: "عرض الملفات", s: false), Perm(k: "system", n: "حالة النظام", s: false),
        ]),
        ("الاشتراكات والأسعار", [
            Perm(k: "gate.state", n: "تغيير حالة الاشتراكات", s: false), Perm(k: "gate.schedule", n: "جدولة الفتح والإغلاق", s: false),
            Perm(k: "gate", n: "أزرار صندوق الاشتراك والعدّاد", s: false), Perm(k: "plans", n: "تعديل الباقات والأسعار", s: false),
        ]),
        ("المحتوى", [
            Perm(k: "content", n: "تعديل المحتوى والصفحات", s: false), Perm(k: "texts", n: "تعديل نصوص الموقع", s: false), Perm(k: "mood", n: "الترحيب حسب الوقت", s: false),
            Perm(k: "train", n: "وضع التدريب", s: false), Perm(k: "look", n: "المظهر وإظهار الأقسام", s: false),
        ]),
        ("التشغيل والحماية", [
            Perm(k: "mode.maintenance", n: "تفعيل وضع الصيانة", s: true), Perm(k: "mode.offline", n: "إيقاف الموقع", s: true), Perm(k: "geo", n: "حظر الدول والعناوين", s: true),
        ]),
        ("المنتظرون والبوت", [
            Perm(k: "notify", n: "تعديل رسائل البوت", s: false), Perm(k: "waitlist.cast", n: "إرسال التذكير للمنتظرين", s: true), Perm(k: "waitlist.manage", n: "حذف المنتظرين وتصديرهم", s: true),
        ]),
        ("الملفات والتطبيق", [
            Perm(k: "files.upload", n: "رفع الملفات", s: false), Perm(k: "files.delete", n: "حذف الملفات", s: true), Perm(k: "app.notify", n: "إرسال إشعارات للفريق", s: false),
            Perm(k: "app.updates", n: "نشر تحديثات التطبيق", s: true), Perm(k: "app.control", n: "إيقاف التطبيق", s: true), Perm(k: "app.customize", n: "تغيير مظهر التطبيق لنفسه", s: false),
            Perm(k: "history.undo", n: "التراجع عن التعديلات", s: true),
        ]),
    ]
    static let presets: [(String, String, Set<String>)] = [
        ("viewer", "مشاهدة فقط", ["stats", "live", "speed", "waitlist.view", "history.view"]),
        ("editor", "محرّر محتوى", ["stats", "live", "plans", "content", "texts", "mood", "train", "look", "history.view", "files.view", "files.upload"]),
        ("subs", "مدير اشتراكات", ["stats", "live", "gate.state", "gate.schedule", "gate", "waitlist.view", "waitlist.cast", "notify", "history.view"]),
        ("assistant", "مساعد كامل", ["stats", "live", "speed", "waitlist.view", "history.view", "log.view", "files.view", "gate.state", "gate.schedule", "gate", "mode.maintenance", "plans", "content", "texts", "mood", "train", "look", "notify", "waitlist.cast", "files.upload", "app.customize", "history.undo"]),
    ]
    static func name(_ k: String) -> String { groups.flatMap(\.1).first { $0.k == k }?.n ?? k }
    static func describe(_ perms: Set<String>) -> String {
        if let p = presets.first(where: { $0.2 == perms }) { return p.1 }
        return perms.isEmpty ? "بلا صلاحيات" : "صلاحيات مخصّصة (\(Fmt.n(perms.count)))"
    }
}

// MARK: - المشرفون
struct UsersView: View {
    @EnvironmentObject var session: Session
    @StateObject private var r = Remote("/users")
    @StateObject private var mon = Remote("/monitor")
    var body: some View {
        Page(title: "المشرفون والصلاحيات", intro: "أضف مشرفين، وحدّد ما يستطيع كل منهم فعله. ما لا يملك المشرف صلاحيته يختفي من تطبيقه كليًا.", id: "users") {
            if session.can("monitor") && mon.loaded {
                SectionTitle("المتصلون الآن", trailing: "يُحدَّث كل 15 ثانية")
                Card {
                    if mon.data["online"].arr.isEmpty { Text("لا يوجد أحد متصل الآن.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                    ForEach(Array(mon.data["online"].arr.enumerated()), id: \.offset) { _, p in
                        HStack(spacing: 12) {
                            Circle().fill(C.ok).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p["name"].str).font(.ox(15, .medium)).foregroundStyle(C.ink)
                                Text("\(p["client"].str == "app" ? "في التطبيق" : "في لوحة التحكم") · \(ScreenNames.name(p["page"].str))").font(.ox(12)).foregroundStyle(C.mute)
                            }
                            Spacer()
                            Text("منذ " + Fmt.span(Int(Date().timeIntervalSince(p["since"].date ?? Date())))).font(.ox(12)).foregroundStyle(C.mute)
                        }.padding(.horizontal, 14).padding(.vertical, 11)
                    }
                }
            }
            if session.isOwner {
                SectionTitle("الحسابات")
                RemoteBody(r: r) {
                    Card {
                        ForEach(Array(r.data["items"].arr.enumerated()), id: \.offset) { _, u in
                            NavigationLink(value: UserRoute(id: u["id"].str)) {
                                RowContent(title: u["name"].str, sub: sub(u), icon: u["role"].str == "owner" ? "crown.fill" : "person.fill", color: u["role"].str == "owner" ? "amber" : "graphite",
                                           pill: !u["active"].isTrue ? ("موقوف", "bad") : nil)
                            }.buttonStyle(RowPress())
                        }
                    }
                }
                Spacer().frame(height: 14)
                NavigationLink(value: UserRoute(id: "new")) {
                    Label("إضافة مشرف", systemImage: "plus").font(.ox(16, .semibold)).foregroundStyle(C.onPrimary)
                        .frame(maxWidth: .infinity).frame(height: 52).background(C.primary, in: Capsule()).padding(.horizontal, 16)
                }.buttonStyle(.plain).accessibilityIdentifier("addUser")
            }
        }
        .task { if session.isOwner { await r.load() }; if session.can("monitor") { await mon.load(); mon.every(15) } }
        .onDisappear { mon.stop() }
        .refreshable { await r.load(); await mon.load() }
        .onReceive(NotificationCenter.default.publisher(for: .orvexUsersChanged)) { _ in Task { await r.load() } }
    }
    func sub(_ u: JSON) -> String {
        let who = u["role"].str == "owner" ? "المسؤول الرئيسي" : PermCatalog.describe(Set(u["perms"].keys.filter { u["perms"][$0].isTrue }))
        let seen = u["seen"].isNull ? "لم يدخل بعد" : "آخر ظهور " + Fmt.ago(u["seen"].date)
        return "@\(u["username"].str) · \(who) · \(seen)"
    }
}
extension Notification.Name { static let orvexUsersChanged = Notification.Name("orvex.users.changed") }

/// أسماء الصفحات في سجل المتصلين
@MainActor
enum ScreenNames {
    static let map: [String: String] = ["home": "الرئيسية", "site": "الموقع", "gate": "حالة الاشتراكات", "schedule": "الجدولة", "plans": "الباقات", "sections": "أقسام الصفحة", "faq": "الأسئلة", "pages": "الصفحات", "links": "الروابط", "texts": "نصوص الموقع", "look": "المظهر", "mood": "الترحيب", "seo": "محركات البحث", "mode": "وضع الموقع", "geo": "الحظر", "stats": "الإحصاءات", "live": "المتصفحون الآن", "speed": "السرعة", "admin": "الإدارة", "waitlist": "المنتظرون", "cast": "إرسال تذكير", "casts": "الرسائل المرسلة", "users": "المشرفون", "history": "سجل التعديلات", "log": "سجل النشاط", "files": "الملفات", "app-updates": "تحديثات التطبيق", "app-control": "التحكم بالتطبيق", "system": "حالة النظام", "inbox": "الإشعارات", "notify-send": "إرسال إشعار", "settings": "الإعدادات", "about": "حول التطبيق", "search": "البحث", "overview": "الرئيسية"]
    static func name(_ p: String) -> String { map[p] ?? (Defs.forms[p]?.title ?? (p.isEmpty ? "—" : p)) }
}

// MARK: - تعديل مشرف
struct UserEditView: View {
    let id: String
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) var dismiss
    @StateObject private var r = Remote("/users")
    @State private var u: JSON = .null
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var note = ""
    @State private var active = true
    @State private var perms: Set<String> = []
    @State private var hasExpiry = false
    @State private var expiry = Date().addingTimeInterval(30 * 86400)
    @State private var maxDevices = 0
    @State private var confirmSensitive = false
    @State private var newPw = ""
    @State private var sessions: [JSON] = []
    @State private var activity: JSON = .null
    @State private var askDelete = false
    @State private var filled = false
    var isNew: Bool { id == "new" }
    var isOwnerAcc: Bool { u["role"].str == "owner" }

    var body: some View {
        Page(title: isNew ? "مشرف جديد" : (name.isEmpty ? "مشرف" : name), intro: isNew ? "أنشئ حسابًا ثم حدّد صلاحياته." : "@\(username)", id: "users") {
            SectionTitle("الحساب")
            Card {
                TextBlock(title: "الاسم الظاهر", text: $name)
                TextBlock(title: "اسم المستخدم (بالإنجليزية)", placeholder: "sara", text: $username, ltr: true).disabled(isOwnerAcc || !isNew)
                if isNew { TextBlock(title: "كلمة المرور (8 أحرف على الأقل)", text: $password, ltr: true) }
                if !isOwnerAcc { TextBlock(title: "ملاحظة خاصة بك", text: $note, multiline: true) }
            }
            if !isOwnerAcc {
                SectionTitle("نوع الصلاحية")
                Card(padded: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        FlowChips(options: PermCatalog.presets.map { ($0.0, $0.1) } + [("custom", "مخصّص")], selected: selectedPreset) { k in
                            if let p = PermCatalog.presets.first(where: { $0.0 == k }) { withAnimation(.snappy) { perms = p.2 } }
                        }
                        Label(summary, systemImage: "info.circle.fill").font(.ox(13)).foregroundStyle(C.ink2).lineSpacing(2)
                    }
                }
                ForEach(PermCatalog.groups.indices, id: \.self) { gi in
                    let g = PermCatalog.groups[gi]
                    SectionTitle(g.0)
                    Card {
                        ForEach(g.1.indices, id: \.self) { pi in
                            let p = g.1[pi]
                            ToggleRow(title: p.n, sub: p.s ? "إجراء حسّاس" : nil, isOn: Binding(get: { perms.contains(p.k) }, set: { if $0 { perms.insert(p.k) } else { perms.remove(p.k) } }))
                        }
                    }
                }
                SectionTitle("القيود والأمان")
                Card {
                    ToggleRow(title: "الحساب مفعّل", sub: active ? nil : "لا يستطيع الدخول", isOn: $active)
                    ToggleRow(title: "تأكيد الإجراءات الحسّاسة بكلمة المرور", sub: "يُطلب منه إدخال كلمة المرور قبل تنفيذ أي إجراء حسّاس", isOn: $confirmSensitive)
                    HStack {
                        Text("عدد الأجهزة المسموح بها").font(.ox(15.5, .medium)).foregroundStyle(C.ink)
                        Spacer()
                        Stepper(value: $maxDevices, in: 0...10) { Text(maxDevices == 0 ? "بلا حد" : Fmt.n(maxDevices)).font(.ox(15, .semibold)).foregroundStyle(C.ink2) }.fixedSize()
                    }.padding(.horizontal, 14).frame(minHeight: 54)
                    ToggleRow(title: "ينتهي الحساب في تاريخ محدّد", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("تاريخ الانتهاء", selection: $expiry, in: Date()..., displayedComponents: [.date])
                            .font(.ox(15)).environment(\.timeZone, Fmt.baghdad).padding(.horizontal, 14).frame(minHeight: 52)
                    }
                }
            }
            Spacer().frame(height: 18)
            PrimaryButton(title: isNew ? "إنشاء الحساب" : "حفظ التغييرات", icon: "checkmark", disabled: name.isEmpty || username.count < 3 || (isNew && password.count < 8)) { await save() }

            if !isNew {
                if !activity.isNull {
                    SectionTitle("آخر نشاط")
                    Card {
                        let log = activity["log"].arr
                        if log.isEmpty { Text("لا يوجد نشاط مسجّل.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                        ForEach(Array(log.prefix(8).enumerated()), id: \.offset) { _, l in LogRow(l: l, showUser: false) }
                    }
                    if !activity["periods"].arr.isEmpty {
                        SectionTitle("فترات الاتصال")
                        Card {
                            ForEach(Array(activity["periods"].arr.prefix(6).enumerated()), id: \.offset) { _, p in
                                InfoRow(title: Fmt.date(p["start"].date), value: Fmt.dur((p["end"].date ?? Date()).timeIntervalSince(p["start"].date ?? Date())))
                            }
                        }
                    }
                }
                SectionTitle("الأجهزة المسجّلة", trailing: Fmt.n(sessions.count))
                Card {
                    if sessions.isEmpty { Text("لا توجد أجهزة مسجّلة.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                    ForEach(Array(sessions.enumerated()), id: \.offset) { _, s in
                        InfoRow(title: (s["client"].str == "app" ? "التطبيق" : "المتصفح") + " · " + flag(s["country"].str) + " " + s["ip"].str, value: Fmt.ago(s["last_seen"].date))
                    }
                    ActionRow(title: "تسجيل خروجه من كل الأجهزة", icon: "iphone.slash", tone: "warn") { await act("/revoke", [:], "سُجّل خروجه من كل الأجهزة."); await loadSessions() }
                }
                if !isOwnerAcc {
                    SectionTitle("كلمة المرور")
                    Card {
                        TextBlock(title: "كلمة مرور جديدة", text: $newPw, ltr: true)
                        ActionRow(title: "تغيير كلمة المرور", icon: "key.fill") {
                            guard newPw.count >= 8 else { Toasts.shared.show("كلمة المرور يجب أن تكون 8 أحرف على الأقل.", "warn"); return }
                            await act("/password", ["password": .string(newPw)], "تغيّرت كلمة المرور."); newPw = ""
                        }
                    }
                    Spacer().frame(height: 18)
                    Card { ActionRow(title: "حذف الحساب", icon: "trash", tone: "bad") { askDelete = true } }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await r.load(); fill(); if !isNew { await loadSessions(); if session.can("monitor") { activity = (try? await API.shared.get("/monitor/user/\(id)")) ?? .null } } }
        .confirmationDialog("حذف حساب \(name)؟", isPresented: $askDelete, titleVisibility: .visible) {
            Button("حذف نهائيًا", role: .destructive) { Task { await act("/delete", [:], "حُذف الحساب."); NotificationCenter.default.post(name: .orvexUsersChanged, object: nil); dismiss() } }
        }
    }
    var selectedPreset: String { PermCatalog.presets.first { $0.2 == perms }?.0 ?? "custom" }
    var summary: String {
        if perms.isEmpty { return "لن يستطيع رؤية أي شيء سوى الرئيسية." }
        let names = PermCatalog.groups.flatMap(\.1).filter { perms.contains($0.k) }.map(\.n)
        return "يستطيع: " + names.prefix(4).joined(separator: "، ") + (names.count > 4 ? "، و\(Fmt.n(names.count - 4)) صلاحيات أخرى." : ".")
    }
    func fill() {
        guard !filled else { return }
        filled = true
        guard !isNew, let x = r.data["items"].arr.first(where: { $0["id"].str == id }) else { return }
        u = x; name = x["name"].str; username = x["username"].str; note = x["note"].str; active = x["active"].isTrue
        perms = Set(x["perms"].keys.filter { x["perms"][$0].isTrue })
        if let e = x["expires_at"].date, e.timeIntervalSince1970 > 0 { hasExpiry = true; expiry = e }
        maxDevices = x["max_devices"].int ?? 0; confirmSensitive = x["confirm_sensitive"].isTrue
    }
    var payload: JSON {
        var p = JObject(); for k in perms.sorted() { p[k] = true }
        return ["name": .string(name), "username": .string(username.lowercased()), "note": .string(note), "active": .bool(active), "perms": .object(p),
                "expires_at": hasExpiry ? .number((expiry.timeIntervalSince1970 * 1000).rounded()) : .number(0), "max_devices": .number(Double(maxDevices)), "confirm_sensitive": .bool(confirmSensitive)]
    }
    func save() async {
        do {
            if isNew {
                var b = payload; b["password"] = .string(password)
                try await API.shared.post("/users", b)
                Toasts.shared.show("أُضيف \(name) إلى الفريق.")
                NotificationCenter.default.post(name: .orvexUsersChanged, object: nil)
                dismiss()
            } else {
                try await API.shared.post("/users/\(id)", isOwnerAcc ? ["name": .string(name)] : payload)
                Toasts.shared.show("حُفظت التغييرات.")
                NotificationCenter.default.post(name: .orvexUsersChanged, object: nil)
            }
        } catch { Toasts.shared.error(error) }
    }
    func act(_ a: String, _ b: JSON, _ ok: String) async {
        do { try await API.shared.post("/users/\(id)\(a)", b); Toasts.shared.show(ok) } catch { Toasts.shared.error(error) }
    }
    func loadSessions() async {
        if let x = try? await API.shared.post("/users/\(id)/sessions") { sessions = x["sessions"].arr }
    }
}

/// شرائح تلتف على أكثر من سطر
struct FlowChips: View {
    var options: [(String, String)]
    var selected: String
    var onTap: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options.indices, id: \.self) { i in
                let o = options[i], on = selected == o.0
                Button { onTap(o.0); Haptics.tap() } label: {
                    Text(o.1).font(.ox(13.5, on ? .semibold : .regular)).foregroundStyle(on ? C.onPrimary : C.ink2)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(on ? C.primary : C.fill, in: Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier("preset-" + o.0)
            }
        }
    }
}
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > b.maxX && x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - سجل التعديلات
struct HistoryView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @State private var items: [JSON] = []
    @State private var total = 0
    @State private var loading = false
    @State private var end = false
    var body: some View {
        Page(title: "سجل التعديلات", intro: "كل حفظ يُنشئ نسخة كاملة من الموقع، ويمكنك التراجع عن أي تعديل أو استعادة أي نسخة.", id: "history") {
            SectionTitle(total == 1 ? "نسخة واحدة" : "\(Fmt.n(total)) نسخة محفوظة")
            Card {
                ForEach(Array(items.enumerated()), id: \.offset) { i, v in
                    NavigationLink(value: VersionRoute(id: v["id"].int ?? 0)) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(v["uname"].str.prefix(1)).uppercased()).font(.ox(13, .semibold)).foregroundStyle(C.ink).frame(width: 32, height: 32).background(C.fill, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(v["what"].str).font(.ox(14.5, .medium)).foregroundStyle(C.ink).lineLimit(3).multilineTextAlignment(.leading)
                                Text("\(v["uname"].str) · \(Fmt.date(v["at"].date))\(v["kind"].str == "undo" ? " · تراجع" : v["kind"].str == "restore" ? " · استعادة" : "")").font(.ox(12)).foregroundStyle(C.mute)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.mute.opacity(0.6)).padding(.top, 8)
                        }.padding(.horizontal, 14).padding(.vertical, 11).contentShape(Rectangle())
                    }
                    .buttonStyle(RowPress())
                    .onAppear { if i == items.count - 1 { Task { await more() } } }
                }
            }
            if loading { ProgressView().frame(maxWidth: .infinity).padding() }
        }
        .task { if items.isEmpty { await reload() } }
        .refreshable { await reload() }
    }
    func reload() async { items = []; end = false; await more() }
    func more() async {
        guard !loading, !end else { return }
        loading = true; defer { loading = false }
        let before = items.last?["id"].int.map { "&before=\($0)" } ?? ""
        do {
            let r = try await API.shared.get("/history?limit=40" + before)
            total = r["total"].int ?? 0
            let n = r["items"].arr; items += n
            if n.count < 40 { end = true }
        } catch { Toasts.shared.error(error) }
    }
}

struct VersionDetailView: View {
    let id: Int
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @StateObject private var r: Remote
    @State private var askRestore = false
    @State private var conflicts: [JSON] = []
    init(id: Int) { self.id = id; _r = StateObject(wrappedValue: Remote("/history/\(id)")) }
    var body: some View {
        let it = r.data["item"]
        Page(title: "تفاصيل التعديل", intro: "\(it["uname"].str) · \(Fmt.date(it["at"].date))", id: "history") {
            RemoteBody(r: r) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 6)
                    Card(padded: true) { Text(it["what"].str).font(.ox(16, .semibold)).foregroundStyle(C.ink).frame(maxWidth: .infinity, alignment: .leading) }
                    if session.can("history.undo") {
                        SectionTitle("الإجراءات")
                        Card {
                            ActionRow(title: "التراجع عن هذا التعديل فقط", icon: "arrow.uturn.backward") { await undo(force: false) }
                            ActionRow(title: "إرجاع الموقع كاملًا إلى هذه النسخة", icon: "clock.arrow.circlepath", tone: "warn") { askRestore = true }
                        }
                        SectionFooter("التراجع يعيد ما تغيّر في هذا الحفظ فقط. الاستعادة تعيد الموقع كله كما كان في هذه النسخة.")
                    }
                    if !conflicts.isEmpty {
                        SectionTitle("تنبيه")
                        Note(text: "تغيّرت بعض هذه الإعدادات بعد هذا التعديل. إذا تابعت، ستعود إلى قيمها القديمة.", tone: "warn", icon: "exclamationmark.triangle.fill")
                        Spacer().frame(height: 10)
                        Card { ActionRow(title: "التراجع رغم ذلك", icon: "arrow.uturn.backward", tone: "bad") { await undo(force: true) } }
                    }
                    SectionTitle("ما الذي تغيّر", trailing: Fmt.n(r.data["changes"].arr.count))
                    Card {
                        if r.data["changes"].arr.isEmpty { Text(r.data["prevId"].isNull ? "هذه أول نسخة محفوظة." : "لا توجد فروق.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                        ForEach(Array(r.data["changes"].arr.prefix(60).enumerated()), id: \.offset) { _, c in ChangeRow(c: c) }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await r.load() }
        .confirmationDialog("إرجاع الموقع كاملًا إلى هذه النسخة؟", isPresented: $askRestore, titleVisibility: .visible) {
            Button("إرجاع", role: .destructive) { Task { await restore() } }
        } message: { Text("تُلغى كل التعديلات التي تلتها، وتبقى محفوظة في السجل.") }
    }
    func undo(force: Bool) async {
        do {
            let x = try await API.shared.post("/history/undo", ["id": .number(Double(id)), "force": .bool(force)])
            store.apply(x); conflicts = []
            Toasts.shared.show(x["same"].isTrue ? "القيم الحالية مطابقة للسابق أصلًا." : "تم التراجع عن التعديل.")
            await session.refreshStatus()
        } catch let e as APIError where e.status == 409 { conflicts = e.data["conflicts"].arr }
        catch { Toasts.shared.error(error) }
    }
    func restore() async {
        do { let x = try await API.shared.post("/history/restore", ["id": .number(Double(id))]); store.apply(x); Toasts.shared.show("أُرجع الموقع إلى هذه النسخة."); await session.refreshStatus() }
        catch { Toasts.shared.error(error) }
    }
}

struct ChangeRow: View {
    let c: JSON
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(FieldNames.label(pathFromJSON(c["p"]))).font(.ox(13.5, .semibold)).foregroundStyle(C.ink)
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("قبل").font(.ox(11)).foregroundStyle(C.mute)
                    Text(show(c["before"])).font(.ox(13)).foregroundStyle(C.bad).lineLimit(4)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("بعد").font(.ox(11)).foregroundStyle(C.mute)
                    Text(show(c["after"])).font(.ox(13)).foregroundStyle(C.ok).lineLimit(4)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.horizontal, 14).padding(.vertical, 11)
    }
    func show(_ v: JSON) -> String {
        switch v {
        case .null: return "—"
        case .bool(let b): return b ? "مفعّل" : "معطّل"
        case .string(let s): return s.isEmpty ? "(فارغ)" : (Defs.gateStates.first { $0.0 == s }?.1 ?? s)
        case .number: return v.str
        case .array(let a): return "قائمة من \(Fmt.n(a.count)) عناصر"
        case .object: return v.isI18n ? (v.ar.isEmpty ? "(فارغ)" : v.ar) : (v["enabled"].bool.map { $0 ? "مفعّل" : "معطّل" } ?? "مجموعة إعدادات")
        }
    }
}

// MARK: - سجل الدخول والنشاط
struct ActivityLogView: View {
    @State private var items: [JSON] = []
    @State private var filter = ""
    @State private var loading = false
    @State private var end = false
    let filters: [(String, String)] = [("", "الكل"), ("login", "الدخول"), ("cfg", "التعديلات"), ("user", "المشرفون"), ("cast", "الإرسال"), ("wait", "المنتظرون"), ("file", "الملفات"), ("app", "التطبيق")]
    var body: some View {
        Page(title: "سجل الدخول والنشاط", intro: "كل عملية دخول وكل إجراء نفّذه أي عضو في الفريق.", id: "log") {
            Spacer().frame(height: 6)
            Chips(options: filters, selection: $filter)
            Spacer().frame(height: 12)
            Card {
                if !loading && items.isEmpty { Text("لا يوجد نشاط.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                ForEach(Array(items.enumerated()), id: \.offset) { i, l in
                    LogRow(l: l).onAppear { if i == items.count - 1 { Task { await more() } } }
                }
            }
            if loading { ProgressView().frame(maxWidth: .infinity).padding() }
        }
        .task { if items.isEmpty { await reload() } }
        .refreshable { await reload() }
        .onChange(of: filter) { _, _ in Task { await reload() } }
    }
    func reload() async { items = []; end = false; await more() }
    func more() async {
        guard !loading, !end else { return }
        loading = true; defer { loading = false }
        var q = "/log?"
        if let last = items.last?["id"].int { q += "before=\(last)&" }
        if !filter.isEmpty { q += "action=\(filter)" }
        do { let r = try await API.shared.get(q); let n = r["items"].arr; items += n; if n.count < 60 { end = true } }
        catch { Toasts.shared.error(error) }
    }
}

struct LogRow: View {
    let l: JSON
    var showUser = true
    static let names: [String: (String, String)] = [
        "login": ("سجّل الدخول", "person.crop.circle.badge.checkmark"), "login.fail": ("محاولة دخول فاشلة", "person.crop.circle.badge.xmark"), "login.lock": ("قُفل الدخول مؤقتًا", "lock.fill"), "login.devices": ("رُفض الدخول لتجاوز عدد الأجهزة", "iphone.slash"),
        "logout": ("سجّل الخروج", "rectangle.portrait.and.arrow.right"), "cfg.save": ("عدّل الموقع", "pencil"), "history.undo": ("تراجع عن تعديل", "arrow.uturn.backward"), "history.restore": ("استعاد نسخة", "clock.arrow.circlepath"),
        "user.create": ("أضاف مشرفًا", "person.badge.plus"), "user.update": ("عدّل مشرفًا", "person.fill.questionmark"), "user.delete": ("حذف مشرفًا", "person.badge.minus"), "user.password": ("غيّر كلمة مرور مشرف", "key.fill"), "user.revoke": ("أخرج مشرفًا من أجهزته", "xmark.circle"),
        "cast.start": ("بدأ إرسال التذكير", "paperplane.fill"), "cast.done": ("اكتمل الإرسال", "checkmark.circle"), "cast.stop": ("أوقف الإرسال", "stop.circle"), "wait.remove": ("حذف من المنتظرين", "trash"), "wait.clear": ("مسح قائمة المنتظرين", "trash.fill"), "wait.export": ("صدّر قائمة المنتظرين", "square.and.arrow.up"),
        "file.upload": ("رفع ملفًا", "arrow.up.doc"), "file.delete": ("حذف ملفًا", "trash"), "app.update": ("نشر تحديثًا للتطبيق", "arrow.down.app"), "note.send": ("أرسل إشعارًا", "bell.fill"),
        "me.password": ("غيّر كلمة مروره", "key"), "me.pin": ("غيّر رمزه السري", "number.circle"), "me.revoke": ("أخرج أجهزته الأخرى", "xmark.circle"), "system.backup": ("نزّل نسخة احتياطية", "arrow.down.doc"), "system.webhooks": ("أعاد ربط البوتات", "link"), "system.version": ("غيّر إعدادات الإصدار", "number"), "confirm.fail": ("أدخل تأكيدًا خاطئًا", "exclamationmark.shield"), "setup.owner": ("أنشأ الحساب الرئيسي", "crown"),
    ]
    var body: some View {
        let a = l["action"].str, info = LogRow.names[a] ?? (a, "circle.fill"), bad = a.contains("fail") || a.contains("lock")
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.1).font(.system(size: 14, weight: .medium)).foregroundStyle(bad ? C.bad : C.ink2).frame(width: 30, height: 30).background(bad ? C.toneBG("bad") : C.fill, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text((showUser && !l["uname"].str.isEmpty ? l["uname"].str + " " : "") + info.0).font(.ox(14.5, .medium)).foregroundStyle(C.ink)
                if !l["detail"].str.isEmpty { Text(l["detail"].str).font(.ox(12.5)).foregroundStyle(C.ink2).lineLimit(3) }
                Text("\(Fmt.ago(l["at"].date))\(l["ip"].str.isEmpty ? "" : " · \(flag(l["country"].str)) \(l["ip"].str)")").font(.ox(11.5)).foregroundStyle(C.mute)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - الإشعارات
struct InboxView: View {
    @EnvironmentObject var session: Session
    @StateObject private var r = Remote("/inbox")
    var body: some View {
        Page(title: "الإشعارات", intro: "التنبيهات المهمة والرسائل من الفريق.", id: "inbox") {
            RemoteBody(r: r) {
                if r.data["items"].arr.isEmpty { EmptyState(icon: "bell.slash", title: "لا توجد إشعارات", sub: "ستظهر هنا التنبيهات والتحديثات.") }
                else {
                    Spacer().frame(height: 6)
                    Card {
                        ForEach(Array(r.data["items"].arr.enumerated()), id: \.offset) { _, n in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: n["level"].str == "bad" ? "exclamationmark.octagon.fill" : n["level"].str == "warn" ? "exclamationmark.triangle.fill" : n["kind"].str == "update" ? "arrow.down.app.fill" : "bell.fill")
                                    .font(.system(size: 15)).foregroundStyle(C.tone(["bad": "bad", "warn": "warn", "ok": "ok"][n["level"].str] ?? "info"))
                                    .frame(width: 32, height: 32).background(C.toneBG(["bad": "bad", "warn": "warn", "ok": "ok"][n["level"].str] ?? "info"), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(n["title"].str).font(.ox(15, .semibold)).foregroundStyle(C.ink)
                                    if !n["body"].str.isEmpty { Text(n["body"].str).font(.ox(13.5)).foregroundStyle(C.ink2).lineSpacing(2) }
                                    Text("\(n["by"].str) · \(Fmt.ago(n["at"].date))").font(.ox(11.5)).foregroundStyle(C.mute)
                                }
                                Spacer(minLength: 0)
                                if !n["read"].isTrue { Circle().fill(C.info).frame(width: 8, height: 8).padding(.top, 6) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture { if n["link"].str == "update" { Router.shared.open("update") } }
                        }
                    }
                }
            }
        }
        .task { await r.load(); if let x = try? await API.shared.post("/inbox/read", ["all": true]) { session.unread = x["unread"].int ?? 0 } }
        .refreshable { await r.load() }
    }
}

// MARK: - إرسال إشعار للفريق
struct SendNoteView: View {
    @StateObject private var sent = Remote("/notes")
    @State private var title = ""
    @State private var text = ""
    @State private var level = "info"
    @State private var target = "all"
    var body: some View {
        Page(title: "إرسال إشعار للفريق", intro: "يظهر الإشعار داخل تطبيق المشرفين. التنبيهات المهمة تظهر فور فتح التطبيق.", id: "notify-send") {
            SectionTitle("الإشعار")
            Card {
                TextBlock(title: "العنوان", text: $title)
                TextBlock(title: "النص (اختياري)", text: $text, multiline: true)
                ChoiceRow(title: "النوع", options: [("info", "معلومة"), ("ok", "خبر سار"), ("warn", "تنبيه"), ("bad", "مهم جدًا")], selection: $level)
                ChoiceRow(title: "إلى", options: [("all", "الجميع"), ("mods", "المشرفون فقط"), ("owner", "المسؤول الرئيسي")], selection: $target)
            }
            Spacer().frame(height: 16)
            PrimaryButton(title: "إرسال", icon: "paperplane.fill", disabled: title.trimmingCharacters(in: .whitespaces).isEmpty) { await send() }
            if !sent.data["items"].arr.isEmpty {
                SectionTitle("المرسلة سابقًا")
                Card {
                    ForEach(Array(sent.data["items"].arr.prefix(20).enumerated()), id: \.offset) { _, n in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n["title"].str).font(.ox(14.5, .medium)).foregroundStyle(C.ink)
                                Text("\(Fmt.ago(n["at"].date)) · قرأه \(Fmt.n(n["reads"]))").font(.ox(12)).foregroundStyle(C.mute)
                            }
                            Spacer()
                            Button { Task { _ = try? await API.shared.post("/notes/\(n["id"].str)/delete"); await sent.load() } } label: { Image(systemName: "trash").foregroundStyle(C.bad) }.buttonStyle(.plain).accessibilityLabel("حذف")
                        }.padding(.horizontal, 14).padding(.vertical, 10)
                    }
                }
            }
        }
        .task { await sent.load() }
    }
    func send() async {
        do {
            try await API.shared.post("/notes", ["title": .string(title), "body": .string(text), "level": .string(level), "target": .string(target)])
            title = ""; text = ""; Toasts.shared.show("أُرسل الإشعار."); await sent.load()
        } catch { Toasts.shared.error(error) }
    }
}
