import SwiftUI

// MARK: - سجل التعديلات
struct HistoryView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @State private var items: [JSON] = []
    @State private var total = 0
    @State private var loading = false
    @State private var end = false
    var body: some View {
        List {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { i, v in
                    VersionRow(v: v).onAppear { if i == items.count - 1 { Task { await more() } } }
                }
                if loading { HStack { Spacer(); ProgressView(); Spacer() } }
            } header: { Text("\(Fmt.n(total)) نسخة محفوظة") } footer: { Text("كل حفظ ياخذ نسخة كاملة من الموقع. اسحب لليسار للتراجع.").font(.ox(12)) }
        }
        .listStyle(.insetGrouped)
        .oxScreen("سجل التعديلات", page: "history")
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
            let n = r["items"].arr
            items += n
            if n.count < 40 { end = true }
        } catch { Toasts.shared.error(error) }
    }
}

struct VersionRow: View {
    let v: JSON
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    var kindInfo: (String, String) {
        switch v["kind"].str {
        case "undo": return ("arrow.uturn.backward.circle.fill", "info")
        case "restore": return ("clock.arrow.circlepath", "warn")
        case "import": return ("square.and.arrow.down.fill", "warn")
        case "base": return ("flag.fill", "mute")
        case "bot": return ("paperplane.fill", "info")
        default: return ("pencil.circle.fill", "accent")
        }
    }
    var body: some View {
        let t = prefs.theme
        NavigationLink(value: VersionRoute(id: v["id"].int ?? 0)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kindInfo.0).font(.system(size: 20)).foregroundStyle(toneColor(kindInfo.1, t) ?? t.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(v["what"].str).font(.ox(14.5, .medium)).lineLimit(3)
                    HStack(spacing: 6) {
                        if !v["uname"].str.isEmpty { Text(v["uname"].str) }
                        Text("·"); Text(Fmt.ago(v["at"].date))
                        if v["via"].str == "bot" { Text("· من البوت") }
                        if v["via"].str == "app" { Image(systemName: "iphone").font(.system(size: 10)) }
                    }.font(.ox(11.5)).foregroundStyle(t.mute)
                }
                Spacer(minLength: 0)
                Text("#\(v["id"].str)").font(.num(11, .regular)).foregroundStyle(t.mute)
            }
        }
        .swipeActions {
            if session.can("history.undo") && v["kind"].str != "base" {
                Button { Task { await store.undo(v["id"].int ?? 0) } } label: { Label("تراجع", systemImage: "arrow.uturn.backward") }.tint(t.info)
            }
        }
    }
}

struct VersionDetailView: View {
    let id: Int
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    @StateObject private var r: Remote
    @State private var askRestore = false
    @State private var conflicts: [JSON] = []
    init(id: Int) { self.id = id; _r = StateObject(wrappedValue: Remote("/history/\(id)")) }
    var body: some View {
        let t = prefs.theme, it = r.data["item"]
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(it["what"].str).font(.ox(17, .semibold))
                    Text("\(it["uname"].str) · \(Fmt.date(it["at"].date)) · نسخة #\(it["id"].str)").font(.ox(12.5)).foregroundStyle(t.mute)
                }.padding(.vertical, 4)
            }
            if session.can("history.undo") {
                Section {
                    AsyncButton(action: { await undo(force: false) }) { Label("تراجع عن هذا التعديل بس", systemImage: "arrow.uturn.backward") }
                    Button { askRestore = true } label: { Label("رجّع الموقع كله لهذي النسخة", systemImage: "clock.arrow.circlepath") }.foregroundStyle(t.warn)
                } footer: { Text("التراجع يرجّع بس الأشياء اللي تغيّرت بهذا الحفظ. الاستعادة ترجّع كل الموقع مثل ما كان.").font(.ox(12)) }
            }
            if !conflicts.isEmpty {
                Section {
                    Text("هذي الإعدادات تغيّرت من بعد هذا التعديل. إذا تكمّل راح ترجع لقيمها القديمة:").font(.ox(13)).foregroundStyle(t.warn)
                    ForEach(Array(conflicts.enumerated()), id: \.offset) { _, c in ChangeRow(c: c) }
                    AsyncButton(role: .destructive, action: { await undo(force: true) }) { Text("تراجع بالقوة") }
                } header: { Text("تعارض") }
            }
            Section("شنو تغيّر (\(Fmt.n(r.data["changes"].arr.count)))") {
                if r.loaded && r.data["changes"].arr.isEmpty { Text(r.data["prevId"].isNull ? "هذي أول نسخة" : "ماكو فرق").font(.ox(14)).foregroundStyle(t.mute) }
                ForEach(Array(r.data["changes"].arr.enumerated()), id: \.offset) { _, c in ChangeRow(c: c) }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .oxScreen("نسخة #\(id)", page: "history")
        .navigationBarTitleDisplayMode(.inline)
        .task { await r.load() }
        .confirmationDialog("ترجع الموقع كله لنسخة #\(id)؟", isPresented: $askRestore, titleVisibility: .visible) {
            Button("إي، رجّعه", role: .destructive) { Task { await restore() } }
        } message: { Text("كل التعديلات اللي صارت بعدها تنلغي (بس تبقى بالسجل وتكدر ترجعلها).") }
    }
    func undo(force: Bool) async {
        do {
            let x = try await API.shared.post("/history/undo", ["id": .number(Double(id)), "force": .bool(force)])
            store.apply(x); conflicts = []
            Toasts.shared.show(x["same"].isTrue ? "كل شي راجع أصلًا" : "تم التراجع ✓")
            await r.load()
        } catch let e as APIError where e.status == 409 {
            conflicts = e.data["conflicts"].arr
        } catch { Toasts.shared.error(error) }
    }
    func restore() async {
        do { let x = try await API.shared.post("/history/restore", ["id": .number(Double(id))]); store.apply(x); Toasts.shared.show("رجع الموقع لنسخة #\(id) ✓") }
        catch { Toasts.shared.error(error) }
    }
}

struct ChangeRow: View {
    let c: JSON
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let t = prefs.theme, p = pathFromJSON(c["p"])
        VStack(alignment: .leading, spacing: 6) {
            Text(Labels.pathLabel(p, store: store)).font(.ox(13.5, .semibold))
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("قبل").font(.ox(10.5)).foregroundStyle(t.mute)
                    Text(show(c["before"])).font(.ox(13)).foregroundStyle(t.bad).strikethrough(true, color: t.bad.opacity(0.5)).lineLimit(5)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.left").font(.system(size: 11)).foregroundStyle(t.mute).padding(.top, 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text("بعد").font(.ox(10.5)).foregroundStyle(t.mute)
                    Text(show(c["after"])).font(.ox(13)).foregroundStyle(t.ok).lineLimit(5)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if !c["now"].isNull && c["now"] != c["after"] { Text("هسه: " + show(c["now"])).font(.ox(11.5)).foregroundStyle(t.warn).lineLimit(2) }
        }.padding(.vertical, 3)
    }
    func show(_ v: JSON) -> String {
        switch v {
        case .null: return "—"
        case .bool(let b): return b ? "شغّال" : "مطفي"
        case .string(let s): return s.isEmpty ? "(فاضي)" : s
        case .number: return v.str
        case .array(let a): return "قائمة (\(Fmt.n(a.count)))"
        case .object: return v.isI18n ? (v.ar.isEmpty ? "(فاضي)" : v.ar) : (v["enabled"].bool.map { $0 ? "شغّال" : "مطفي" } ?? "مجموعة إعدادات")
        }
    }
}

// MARK: - سجل النشاط
struct ActivityLogView: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var items: [JSON] = []
    @State private var filter = ""
    @State private var loading = false
    @State private var end = false
    let filters: [(String, String)] = [("", "الكل"), ("login", "الدخول"), ("cfg", "التعديلات"), ("user", "المشرفين"), ("cast", "الإرسال"), ("wait", "المنتظرين"), ("file", "الملفات"), ("history", "التراجع"), ("app", "التطبيق"), ("system", "النظام")]
    var body: some View {
        List {
            Section { Chips(options: filters, selection: $filter).listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { i, l in
                    LogRow(l: l).onAppear { if i == items.count - 1 { Task { await more() } } }
                }
                if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                if !loading && items.isEmpty { Text("ماكو نشاط").font(.ox(14)).foregroundStyle(prefs.theme.mute) }
            }
        }
        .listStyle(.insetGrouped)
        .oxScreen("سجل النشاط", page: "log")
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
    @ObservedObject var prefs = Prefs.shared
    static let names: [String: (String, String)] = [
        "login": ("دخل", "person.crop.circle.badge.checkmark"), "login.fail": ("محاولة دخول فاشلة", "person.crop.circle.badge.xmark"), "login.lock": ("انقفل بعد محاولات فاشلة", "lock.fill"), "login.devices": ("رفض لأن الأجهزة اكتملت", "iphone.slash"),
        "logout": ("طلع", "rectangle.portrait.and.arrow.right"), "cfg.save": ("عدّل الموقع", "pencil"), "history.undo": ("تراجع", "arrow.uturn.backward"), "history.restore": ("استعاد نسخة", "clock.arrow.circlepath"),
        "user.create": ("أضاف مشرف", "person.badge.plus"), "user.update": ("عدّل مشرف", "person.fill.questionmark"), "user.delete": ("حذف مشرف", "person.badge.minus"), "user.password": ("غيّر كلمة سر مشرف", "key.fill"), "user.revoke": ("طلّع مشرف من الأجهزة", "xmark.circle"),
        "cast.start": ("بدأ إرسال جماعي", "paperplane.fill"), "cast.done": ("خلص الإرسال", "checkmark.circle"), "cast.stop": ("أوقف الإرسال", "stop.circle"), "wait.remove": ("حذف منتظرين", "trash"), "wait.clear": ("مسح القائمة", "trash.fill"), "wait.export": ("صدّر القائمة", "square.and.arrow.up"),
        "file.upload": ("رفع ملف", "arrow.up.doc"), "file.delete": ("حذف ملف", "trash"), "app.update": ("نشر تحديث للتطبيق", "arrow.down.app"), "note.send": ("أرسل إشعار", "bell.fill"),
        "me.password": ("غيّر كلمة سره", "key"), "me.pin": ("الرمز السري", "number.circle"), "me.revoke": ("طلّع أجهزته", "xmark.circle"), "system.backup": ("نزّل نسخة احتياطية", "arrow.down.doc"), "system.import": ("استورد نسخة", "square.and.arrow.down"), "system.webhooks": ("أعاد ربط البوتات", "link"), "system.version": ("إعدادات الإصدار", "number"), "confirm.fail": ("تأكيد خاطئ", "exclamationmark.shield"),
    ]
    var body: some View {
        let t = prefs.theme, a = l["action"].str
        let info = LogRow.names[a] ?? (a, "circle.fill")
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.1).font(.system(size: 14)).foregroundStyle(a.contains("fail") || a.contains("lock") ? t.bad : t.accent).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if showUser && !l["uname"].str.isEmpty { Text(l["uname"].str).font(.ox(14, .semibold)) }
                    Text(info.0).font(.ox(14))
                }
                if !l["detail"].str.isEmpty { Text(l["detail"].str).font(.ox(12.5)).foregroundStyle(t.ink2).lineLimit(3) }
                Text("\(Fmt.ago(l["at"].date))\(l["ip"].str.isEmpty ? "" : " · \(flag(l["country"].str)) \(l["ip"].str)")").font(.ox(11)).foregroundStyle(t.mute)
            }
        }.padding(.vertical, 2)
    }
}
