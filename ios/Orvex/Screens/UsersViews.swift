import SwiftUI

// MARK: - المشرفين
struct UsersView: View {
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/users")
    var body: some View {
        let t = prefs.theme
        List {
            Section {
                NavigationLink(value: UserRoute(id: "new")) { RowLabel(title: "أضف مشرف جديد", icon: "person.badge.plus", tint: t.ok) }.accessibilityIdentifier("addUser")
            }
            Section("الحسابات") {
                ForEach(Array(r.data["items"].arr.enumerated()), id: \.offset) { _, u in
                    NavigationLink(value: UserRoute(id: u["id"].str)) { UserRow(u: u) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .oxScreen("المشرفين", page: "users")
        .task { await r.load() }
        .refreshable { await r.load() }
        .onReceive(NotificationCenter.default.publisher(for: .orvexUsersChanged)) { _ in Task { await r.load() } }
    }
}
extension Notification.Name { static let orvexUsersChanged = Notification.Name("orvex.users.changed") }

struct UserRow: View {
    let u: JSON
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        HStack(spacing: 12) {
            Text(String(u["name"].str.prefix(1))).font(.ox(17, .bold)).foregroundStyle(u["role"].str == "owner" ? t.onAccent : t.ink)
                .frame(width: 42, height: 42).background(u["role"].str == "owner" ? t.accent : t.surface2, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(u["name"].str).font(.ox(15.5, .semibold))
                    if u["role"].str == "owner" { Pill(text: "رئيسي", tone: "accent") }
                    if !u["active"].isTrue { Pill(text: "موقوف", tone: "bad") }
                    if let e = u["expires_at"].date, e < Date() { Pill(text: "منتهي", tone: "warn") }
                }
                Text("@\(u["username"].str) · \(u["role"].str == "owner" ? "كل الصلاحيات" : "\(Fmt.n(u["perms"].keys.count)) صلاحية")").font(.ox(12)).foregroundStyle(t.mute)
                Text(u["seen"].isNull ? "ما فات بعد" : "آخر ظهور \(Fmt.ago(u["seen"].date)) · \(Fmt.n(u["sessions"])) جهاز").font(.ox(11.5)).foregroundStyle(t.mute)
            }
        }.padding(.vertical, 2)
    }
}

struct UserEditView: View {
    let id: String
    @ObservedObject var prefs = Prefs.shared
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
    @State private var askDelete = false
    @State private var filled = false
    var isNew: Bool { id == "new" }
    var isOwnerAcc: Bool { u["role"].str == "owner" }

    static let presets: [(String, String, [String])] = [
        ("مشاهد فقط", "eye", ["stats", "live", "speed", "waitlist.view", "history.view"]),
        ("محرر محتوى", "pencil", ["stats", "live", "plans", "content", "texts", "mood", "train", "look", "history.view", "files.view", "files.upload"]),
        ("مدير اشتراكات", "door.left.hand.open", ["stats", "live", "gate.state", "gate.schedule", "gate", "waitlist.view", "waitlist.cast", "notify", "history.view"]),
        ("مساعد كامل", "star", ["stats", "live", "speed", "waitlist.view", "history.view", "log.view", "files.view", "gate.state", "gate.schedule", "gate", "mode.maintenance", "plans", "content", "texts", "mood", "train", "look", "notify", "waitlist.cast", "files.upload", "app.customize", "history.undo"]),
    ]

    var body: some View {
        let t = prefs.theme
        let catalog = r.data["perms"].arr
        let groups = catalog.reduce(into: [String]()) { a, p in if !a.contains(p["g"].str) { a.append(p["g"].str) } }
        Form {
            Section {
                TextField("الاسم الظاهر", text: $name).font(.ox(16)).accessibilityIdentifier("userName")
                TextField("اسم المستخدم (إنجليزي)", text: $username).font(.ox(15)).textInputAutocapitalization(.never).autocorrectionDisabled().environment(\.layoutDirection, .leftToRight).disabled(isOwnerAcc).accessibilityIdentifier("userUsername")
                if isNew { SecureField("كلمة السر (8 أحرف أو أكثر)", text: $password).accessibilityIdentifier("userPassword") }
                if !isOwnerAcc { TextField("ملاحظة (لك بس)", text: $note, axis: .vertical).font(.ox(14)) }
            } header: { Text("الحساب") }

            if !isOwnerAcc {
                Section {
                    Toggle("الحساب شغّال", isOn: $active).font(.ox(15))
                    Toggle("ينتهي بتاريخ", isOn: $hasExpiry).font(.ox(15))
                    if hasExpiry { DatePicker("ينتهي", selection: $expiry, in: Date()..., displayedComponents: [.date, .hourAndMinute]).font(.ox(15)).environment(\.timeZone, Fmt.baghdad) }
                    Stepper(value: $maxDevices, in: 0...20) { Text(maxDevices == 0 ? "عدد الأجهزة: بلا حد" : "عدد الأجهزة: \(Fmt.n(maxDevices))").font(.ox(15)) }
                    Toggle(isOn: $confirmSensitive) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("يأكد الإجراءات الحساسة").font(.ox(15))
                            Text("قبل الصيانة والحظر والإرسال والحذف يطلب رمزه أو الفيس آيدي").font(.ox(12)).foregroundStyle(t.mute)
                        }
                    }
                } header: { Text("القيود والأمان") }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(UserEditView.presets.indices, id: \.self) { i in
                                let p = UserEditView.presets[i]
                                Button { withAnimation { perms = Set(p.2) }; prefs.tap() } label: { Label(p.0, systemImage: p.1).font(.ox(13)) }.buttonStyle(.bordered)
                            }
                            Button { withAnimation { perms = [] } } label: { Label("ولا شي", systemImage: "xmark").font(.ox(13)) }.buttonStyle(.bordered)
                        }
                    }.listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: { Text("الصلاحيات — \(Fmt.n(perms.count)) من \(Fmt.n(catalog.count))") } footer: { Text("اللي ما عنده صلاحيته يختفي من عنده بالكامل، بالتطبيق واللوحة.").font(.ox(12)) }

                ForEach(groups, id: \.self) { g in
                    Section(g) {
                        ForEach(Array(catalog.filter { $0["g"].str == g }.enumerated()), id: \.offset) { _, p in
                            Toggle(isOn: Binding(get: { perms.contains(p["k"].str) }, set: { if $0 { perms.insert(p["k"].str) } else { perms.remove(p["k"].str) } })) {
                                HStack(spacing: 6) {
                                    Text(p["n"].str).font(.ox(14.5))
                                    if p["s"].int == 1 { Image(systemName: "exclamationmark.shield.fill").font(.system(size: 12)).foregroundStyle(t.warn) }
                                }
                            }
                        }
                    }
                }
            }

            Section {
                AsyncButton(action: { await save() }) { Label(isNew ? "أنشئ الحساب" : "احفظ", systemImage: "checkmark").frame(maxWidth: .infinity) }
                    .buttonStyle(.oxProminent).listRowBackground(Color.clear).accessibilityIdentifier("userSave")
                    .disabled(name.isEmpty || username.count < 3 || (isNew && password.count < 8))
            }

            if !isNew {
                if !isOwnerAcc {
                    Section {
                        SecureField("كلمة سر جديدة", text: $newPw)
                        AsyncButton(action: { await act("/password", ["password": .string(newPw)], "تغيّرت كلمة السر"); newPw = "" }) { Text("غيّر كلمة السر") }.disabled(newPw.count < 8)
                    } header: { Text("كلمة السر") }
                }
                Section {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { _, s in
                        HStack {
                            Image(systemName: s["client"].str == "app" ? "iphone" : "safari").foregroundStyle(t.accent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(flag(s["country"].str)) \(s["ip"].str)").font(.ox(13.5))
                                Text("آخر ظهور \(Fmt.ago(s["last_seen"].date))").font(.ox(11.5)).foregroundStyle(t.mute)
                            }
                        }
                    }
                    if sessions.isEmpty { Text("ماكو أجهزة مسجّلة").font(.ox(13.5)).foregroundStyle(t.mute) }
                    AsyncButton(action: { await act("/revoke", [:], "طلع من كل الأجهزة"); await loadSessions() }) { Text("طلّعه من كل الأجهزة") }
                    NavigationLink(value: MonitorRoute(id: id, name: name)) { Label("كل نشاطه ومتى كان أونلاين", systemImage: "eye") }
                } header: { Text("الأجهزة") }
                if !isOwnerAcc {
                    Section { Button(role: .destructive) { askDelete = true } label: { Label("احذف الحساب", systemImage: "trash") } }
                }
            }
        }
        .formStyle(.grouped)
        .oxScreen(isNew ? "مشرف جديد" : name, page: "users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await r.load(); fill(); if !isNew { await loadSessions() } }
        .confirmationDialog("تحذف حساب \(name)؟", isPresented: $askDelete, titleVisibility: .visible) {
            Button("احذف نهائيًا", role: .destructive) { Task { await act("/delete", [:], "انحذف الحساب"); NotificationCenter.default.post(name: .orvexUsersChanged, object: nil); dismiss() } }
        }
    }

    func fill() {
        guard !filled else { return }
        filled = true
        guard !isNew, let x = r.data["items"].arr.first(where: { $0["id"].str == id }) else { return }
        u = x; name = x["name"].str; username = x["username"].str; note = x["note"].str; active = x["active"].isTrue
        perms = Set(x["perms"].keys.filter { x["perms"][$0].isTrue })
        if let e = x["expires_at"].date { hasExpiry = true; expiry = e }
        maxDevices = x["max_devices"].int ?? 0; confirmSensitive = x["confirm_sensitive"].isTrue
    }
    var body0: JSON {
        var p = JObject(); for k in perms.sorted() { p[k] = true }
        return ["name": .string(name), "username": .string(username), "note": .string(note), "active": .bool(active), "perms": .object(p),
                "expires_at": hasExpiry ? .number((expiry.timeIntervalSince1970 * 1000).rounded()) : .number(0), "max_devices": .number(Double(maxDevices)), "confirm_sensitive": .bool(confirmSensitive)]
    }
    func save() async {
        do {
            if isNew {
                var b = body0; b["password"] = .string(password)
                try await API.shared.post("/users", b)
                Toasts.shared.show("انضاف \(name) ✓")
                NotificationCenter.default.post(name: .orvexUsersChanged, object: nil)
                dismiss()
            } else {
                try await API.shared.post("/users/\(id)", isOwnerAcc ? ["name": .string(name)] : body0)
                Toasts.shared.show("انحفظ ✓")
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

// MARK: - المراقبة المباشرة
struct MonitorView: View {
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/monitor")
    var body: some View {
        let t = prefs.theme
        List {
            Section {
                if r.data["online"].arr.isEmpty { Text("ماكو أحد أونلاين هسه").font(.ox(14)).foregroundStyle(t.mute) }
                ForEach(Array(r.data["online"].arr.enumerated()), id: \.offset) { _, p in
                    NavigationLink(value: MonitorRoute(id: p["uid"].str, name: p["name"].str)) {
                        HStack(spacing: 12) {
                            PulseDot(color: t.ok)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(p["name"].str).font(.ox(15, .semibold))
                                    Pill(text: p["client"].str == "app" ? "التطبيق" : "اللوحة", tone: p["client"].str == "app" ? "info" : "mute", icon: p["client"].str == "app" ? "iphone" : "safari")
                                }
                                Text("بصفحة: \(MonitorView.page(p["page"].str))").font(.ox(13)).foregroundStyle(t.ink2)
                                Text("من \(Fmt.dur(Date().timeIntervalSince(p["since"].date ?? Date())))\(p["device"]["model"].isNull ? "" : " · " + p["device"]["model"].str)").font(.ox(11.5)).foregroundStyle(t.mute)
                            }
                        }
                    }
                }
            } header: { HStack { Text("أونلاين هسه"); Spacer(); Text("يتحدث كل 10 ثواني").font(.ox(11)) } }
            Section("كل الحسابات") {
                ForEach(Array(r.data["users"].arr.enumerated()), id: \.offset) { _, u in
                    NavigationLink(value: MonitorRoute(id: u["id"].str, name: u["name"].str)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u["name"].str).font(.ox(15))
                                Text(u["last_seen"].isNull ? "ما فات" : "آخر ظهور \(Fmt.ago(u["last_seen"].date))").font(.ox(12)).foregroundStyle(t.mute)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Fmt.dur((u["today_ms"].double ?? 0) / 1000)).font(.num(13, .semibold))
                                Text("اليوم").font(.ox(10.5)).foregroundStyle(t.mute)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .animation(.snappy, value: r.data["online"])
        .oxScreen("المراقبة المباشرة", page: "monitor")
        .task { await r.load(); r.every(10) }
        .onDisappear { r.stop() }
        .refreshable { await r.load() }
    }
    static let pages: [String: String] = ["home": "الرئيسية", "site": "الموقع", "gate": "الاشتراكات", "mode": "وضع الموقع", "plans": "الباقات", "content": "المحتوى", "texts": "كل كلمة", "mood": "مزاج الوقت", "train": "وضع التدريب", "look": "المظهر", "advanced": "كل الإعدادات", "geo": "الحظر", "stats": "الزوار", "live": "هسه بالموقع", "speed": "السرعة", "telegram": "التيليجرام", "waitlist": "المنتظرين", "cast": "إرسال التذكير", "botmsgs": "رسائل البوت", "more": "المزيد", "inbox": "الإشعارات", "notify-send": "إرسال إشعار", "files": "الملفات", "users": "المشرفين", "monitor": "المراقبة", "history": "سجل التعديلات", "log": "سجل النشاط", "app-updates": "تحديثات التطبيق", "app-control": "التحكم بالتطبيق", "widgets": "الويدجت", "settings": "الإعدادات", "system": "النظام", "account": "حسابي", "about": "حول", "search": "البحث", "overview": "الرئيسية", "notify": "رسائل البوت", "users.edit": "المشرفين"]
    static func page(_ p: String) -> String { pages[p] ?? (p.isEmpty ? "—" : p) }
}

struct MonitorUserView: View {
    let id: String
    let name: String
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r: Remote
    @State private var tab = "log"
    init(id: String, name: String) { self.id = id; self.name = name; _r = StateObject(wrappedValue: Remote("/monitor/user/\(id)")) }
    var body: some View {
        let t = prefs.theme
        List {
            Section {
                Picker("", selection: $tab) { Text("الإجراءات").tag("log"); Text("التعديلات").tag("ver"); Text("الصفحات").tag("pages"); Text("أونلاين").tag("online") }.pickerStyle(.segmented)
            }
            switch tab {
            case "ver":
                Section {
                    ForEach(Array(r.data["versions"].arr.enumerated()), id: \.offset) { _, v in
                        VersionRow(v: v)
                    }
                    if r.data["versions"].arr.isEmpty { Text("ما عدّل شي").foregroundStyle(t.mute).font(.ox(14)) }
                } footer: { Text("اسحب على أي تعديل للتراجع عنه").font(.ox(12)) }
            case "pages":
                Section {
                    ForEach(Array(r.data["pages"].arr.prefix(150).enumerated()), id: \.offset) { _, p in
                        HStack {
                            Image(systemName: p["client"].str == "app" ? "iphone" : "safari").foregroundStyle(t.mute).frame(width: 20)
                            Text(MonitorView.page(p["page"].str)).font(.ox(14))
                            Spacer()
                            Text(Fmt.date(p["at"].date)).font(.ox(11.5)).foregroundStyle(t.mute)
                        }
                    }
                }
            case "online":
                Section {
                    ForEach(Array(r.data["periods"].arr.enumerated()), id: \.offset) { _, p in
                        let s = p["start"].date, e = p["end"].date
                        HStack {
                            Image(systemName: p["client"].str == "app" ? "iphone" : "safari").foregroundStyle(t.accent).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(Fmt.date(s)).font(.ox(14))
                                Text("لحد \(Fmt.time(e))").font(.ox(11.5)).foregroundStyle(t.mute)
                            }
                            Spacer()
                            Text(Fmt.dur((e ?? Date()).timeIntervalSince(s ?? Date()))).font(.num(13, .semibold))
                        }
                    }
                }
            default:
                Section {
                    ForEach(Array(r.data["log"].arr.enumerated()), id: \.offset) { _, l in LogRow(l: l, showUser: false) }
                    if r.data["log"].arr.isEmpty { Text("ماكو نشاط").foregroundStyle(t.mute).font(.ox(14)) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .oxScreen(name, page: "monitor")
        .navigationBarTitleDisplayMode(.inline)
        .task { await r.load() }
        .refreshable { await r.load() }
    }
}
