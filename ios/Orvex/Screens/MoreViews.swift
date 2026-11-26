import SwiftUI

// MARK: - المزيد
struct MoreView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @State private var askLogout = false
    var body: some View {
        let t = prefs.theme
        List {
            Section {
                HStack(spacing: 14) {
                    Text(String(session.name.prefix(1))).font(.ox(22, .bold)).foregroundStyle(t.onAccent).frame(width: 52, height: 52).background(t.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name).font(.ox(18, .semibold))
                        Text("@\(session.me["username"].str) · \(session.isOwner ? "المسؤول الرئيسي" : "مشرف")").font(.ox(12.5)).foregroundStyle(t.mute)
                    }
                    Spacer()
                }.padding(.vertical, 4)
                NavigationLink(value: "inbox") { RowLabel(title: "الإشعارات", icon: "bell.fill", badge: session.unread > 0 ? Fmt.n(session.unread) : nil) }.accessibilityIdentifier("more-inbox")
                if session.can("app.notify") { NavigationLink(value: "notify-send") { RowLabel(title: "أرسل إشعار للمشرفين", icon: "bell.badge.fill") } }
            }
            let admin: [(String, String, String, Bool)] = [
                ("users", "المشرفين والصلاحيات", "person.2.badge.gearshape.fill", session.isOwner),
                ("monitor", "المراقبة المباشرة", "eye.circle.fill", session.can("monitor")),
                ("history", "سجل التعديلات والتراجع", "clock.arrow.circlepath", session.can("history.view")),
                ("log", "سجل النشاط والدخول", "list.bullet.clipboard.fill", session.can("log.view")),
                ("files", "الملفات", "folder.fill", session.can("files.view")),
            ]
            if admin.contains(where: \.3) {
                Section("الإدارة") { ForEach(admin.indices, id: \.self) { i in let a = admin[i]; if a.3 { NavigationLink(value: a.0) { RowLabel(title: a.1, icon: a.2) }.accessibilityIdentifier("more-\(a.0)") } } }
            }
            Section("التطبيق") {
                if session.can("app.updates") { NavigationLink(value: "app-updates") { RowLabel(title: "تحديثات التطبيق", icon: "arrow.down.app.fill") }.accessibilityIdentifier("more-app-updates") }
                if session.can("app.control") { NavigationLink(value: "app-control") { RowLabel(title: "التحكم بالتطبيق", icon: "switch.2") }.accessibilityIdentifier("more-app-control") }
                NavigationLink(value: "widgets") { RowLabel(title: "تخصيص شاشة الآيفون", icon: "widget.small", sub: "الويدجت والجزيرة التفاعلية") }.accessibilityIdentifier("more-widgets")
                NavigationLink(value: "settings") { RowLabel(title: "الإعدادات والمظهر", icon: "gearshape.fill") }.accessibilityIdentifier("more-settings")
            }
            Section {
                if session.can("system") { NavigationLink(value: "system") { RowLabel(title: "حالة النظام", icon: "server.rack") }.accessibilityIdentifier("more-system") }
                NavigationLink(value: "account") { RowLabel(title: "حسابي والأمان", icon: "person.crop.circle.badge.checkmark") }.accessibilityIdentifier("more-account")
                NavigationLink(value: "about") { RowLabel(title: "حول أورفيكس", icon: "info.circle.fill") }.accessibilityIdentifier("more-about")
            }
            Section {
                Button(role: .destructive) { askLogout = true } label: { Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right").font(.ox(15)) }
            }
        }
        .listStyle(.insetGrouped)
        .oxScreen("المزيد", page: "more")
        .confirmationDialog("تطلع من الحساب؟", isPresented: $askLogout, titleVisibility: .visible) {
            Button("تسجيل الخروج", role: .destructive) { Task { await session.logout() } }
        }
    }
}

// MARK: - الإشعارات
struct InboxView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/inbox")
    var body: some View {
        let t = prefs.theme
        List {
            if r.loaded && r.data["items"].arr.isEmpty {
                EmptyState(icon: "bell.slash", text: "ماكو إشعارات", sub: "التنبيهات المهمة والتحديثات توصلك هنا").listRowBackground(Color.clear)
            }
            ForEach(Array(r.data["items"].arr.enumerated()), id: \.offset) { _, n in
                Button { open(n) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(n)).font(.system(size: 16, weight: .semibold)).foregroundStyle(toneColor(tone(n), t) ?? t.accent)
                            .frame(width: 34, height: 34).background((toneColor(tone(n), t) ?? t.accent).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(n["title"].str).font(.ox(15, n["read"].isTrue ? .regular : .semibold)).foregroundStyle(t.ink)
                                Spacer()
                                if !n["read"].isTrue { Circle().fill(t.accent).frame(width: 8, height: 8) }
                            }
                            if !n["body"].str.isEmpty { Text(n["body"].str).font(.ox(13.5)).foregroundStyle(t.ink2).lineLimit(6) }
                            Text("\(n["by"].str) · \(Fmt.ago(n["at"].date))").font(.ox(11.5)).foregroundStyle(t.mute)
                        }
                    }.padding(.vertical, 4)
                }.buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .oxScreen("الإشعارات", page: "inbox")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("قريت الكل") { Task { await readAll() } }.font(.ox(14)).disabled(session.unread == 0)
            }
        }
        .task { await r.load(); await readAll(silent: true) }
        .refreshable { await r.load() }
    }
    func icon(_ n: JSON) -> String {
        switch n["kind"].str { case "update": return "arrow.down.app.fill"; case "system": return "server.rack"; case "cast": return "paperplane.fill"; case "error": return "exclamationmark.triangle.fill"; default: return n["level"].str == "bad" ? "exclamationmark.octagon.fill" : n["level"].str == "warn" ? "exclamationmark.triangle.fill" : "bell.fill" }
    }
    func tone(_ n: JSON) -> String { ["bad": "bad", "warn": "warn", "ok": "ok", "info": "info"][n["level"].str] ?? "accent" }
    func open(_ n: JSON) {
        let l = n["link"].str
        if l == "update", let up = Session.shared.app["update"].object { Session.shared.pendingUpdate = .object(up); return }
        if !l.isEmpty, !l.hasPrefix("http") { Router.shared.open(l) }
        else if let u = URL(string: l), l.hasPrefix("http") { UIApplication.shared.open(u) }
    }
    func readAll(silent: Bool = false) async {
        if let x = try? await API.shared.post("/inbox/read", ["all": true]) { session.unread = x["unread"].int ?? 0; if !silent { await r.load() } }
    }
}

// MARK: - إرسال إشعار
struct SendNoteView: View {
    @ObservedObject var prefs = Prefs.shared
    @EnvironmentObject var session: Session
    @StateObject private var sent = Remote("/notes")
    @StateObject private var users = Remote("/monitor")
    @State private var title = ""
    @State private var text = ""
    @State private var level = "info"
    @State private var target = "all"
    @State private var hours = 0.0
    var body: some View {
        Form {
            Section {
                TextField("العنوان", text: $title).font(.ox(16, .semibold)).accessibilityIdentifier("noteTitle")
                TextField("النص (اختياري)", text: $text, axis: .vertical).font(.ox(15)).lineLimit(3...8)
                Picker("النوع", selection: $level) {
                    Label("معلومة", systemImage: "info.circle").tag("info")
                    Label("نجاح", systemImage: "checkmark.circle").tag("ok")
                    Label("تنبيه", systemImage: "exclamationmark.triangle").tag("warn")
                    Label("مهم جدًا", systemImage: "exclamationmark.octagon").tag("bad")
                }.font(.ox(15))
                Picker("إلى", selection: $target) {
                    Text("الكل").tag("all"); Text("المشرفين بس").tag("mods"); Text("المسؤول الرئيسي").tag("owner")
                    ForEach(Array(users.data["users"].arr.filter { $0["role"].str != "owner" }.enumerated()), id: \.offset) { _, u in Text(u["name"].str).tag("u:" + u["id"].str) }
                }.font(.ox(15))
                Stepper(value: $hours, in: 0...168, step: 6) { Text(hours == 0 ? "يبقى دائمًا" : "يختفي بعد \(Fmt.n(hours)) ساعة").font(.ox(15)) }
            } footer: { Text("«تنبيه» و«مهم جدًا» تطلع كبطاقة فوق الشاشة وبالجزيرة التفاعلية إذا مفعّلة.").font(.ox(12)) }
            Section {
                AsyncButton(action: { await send() }) { Label("أرسل", systemImage: "paperplane.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.oxProminent).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty).listRowBackground(Color.clear)
                    .accessibilityIdentifier("noteSend")
            }
            Section("المرسلة سابقًا") {
                ForEach(Array(sent.data["items"].arr.enumerated()), id: \.offset) { _, n in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(n["title"].str).font(.ox(14.5, .medium))
                        Text("\(Fmt.ago(n["at"].date)) · \(targetName(n["target"].str)) · قراها \(Fmt.n(n["reads"]))").font(.ox(12)).foregroundStyle(prefs.theme.mute)
                    }
                    .swipeActions { Button(role: .destructive) { Task { try? await API.shared.post("/notes/\(n["id"].str)/delete"); await sent.load() } } label: { Label("حذف", systemImage: "trash") } }
                }
            }
        }
        .formStyle(.grouped)
        .oxScreen("أرسل إشعار", page: "notify-send")
        .task { await sent.load(); if session.can("monitor") { await users.load() } }
    }
    func targetName(_ t: String) -> String {
        if t == "all" { return "الكل" }; if t == "mods" { return "المشرفين" }; if t == "owner" { return "المالك" }
        return users.data["users"].arr.first { "u:" + $0["id"].str == t }?["name"].str ?? "مشرف"
    }
    func send() async {
        var b: JSON = ["title": .string(title), "body": .string(text), "level": .string(level), "target": .string(target)]
        if hours > 0 { b["expires_hours"] = .number(hours) }
        do { try await API.shared.post("/notes", b); title = ""; text = ""; Toasts.shared.show("انرسل ✓"); await sent.load() }
        catch { Toasts.shared.error(error) }
    }
}

// MARK: - حالة النظام
struct SystemView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/system?bots=1")
    @StateObject private var errs = Remote("/errors")
    @State private var share: ShareItem?
    var body: some View {
        let t = prefs.theme, d = r.data
        List {
            Section("الحالة") {
                InfoRow(title: "رقم البناء", value: d["build"].str, icon: "hammer.fill")
                InfoRow(title: "إصدار الموقع", value: d["version"].str, icon: "number")
                InfoRow(title: "رقم المراجعة", value: Fmt.n(d["rev"]), icon: "arrow.triangle.2.circlepath")
                InfoRow(title: "آخر تعديل", value: Fmt.ago(d["updatedAt"].date), icon: "clock")
                InfoRow(title: "حجم الإعدادات", value: Fmt.bytes(d["cfgBytes"].double ?? 0), icon: "doc")
                InfoRow(title: "النسخ المحفوظة", value: Fmt.n(d["versions"]), icon: "square.stack.3d.up")
                InfoRow(title: "الحسابات", value: Fmt.n(d["users"]), icon: "person.2")
            }
            Section("الخدمات") {
                InfoRow(title: "تخزين الإعدادات (KV)", value: d["kv"].isTrue ? "شغّال ✓" : "عطلان", icon: "externaldrive.fill", tone: d["kv"].isTrue ? "ok" : "bad")
                InfoRow(title: "قاعدة البيانات (D1)", value: d["d1"].isTrue ? "شغّالة ✓" : "عطلانة", icon: "cylinder.split.1x2.fill", tone: d["d1"].isTrue ? "ok" : "bad")
                InfoRow(title: "المهمة المجدولة (Cron)", value: session.status["cron"].date.map { Fmt.ago($0) } ?? "مو مفعّلة", icon: "timer", tone: session.status["cron"].isNull ? "warn" : "ok")
                ForEach(["BOT_TOKEN", "NOTIFY_BOT_TOKEN", "WEBHOOK_SECRET", "SETUP_CODE"], id: \.self) { k in
                    InfoRow(title: k, value: d["secrets"][k].isTrue ? "موجود" : "ناقص", icon: "key.fill", tone: d["secrets"][k].isTrue ? "ok" : "warn")
                }
            }
            Section("بوتات التيليجرام") {
                bot("بوت التحكم", d["bots"]["control"])
                bot("بوت الإشعارات", d["bots"]["notify"])
                if session.isOwner {
                    AsyncButton(action: { await webhooks() }) { Label("أعد ربط البوتات (Webhooks)", systemImage: "link") }
                }
            }
            if session.isOwner {
                Section {
                    Toggle("ترقيم الإصدار تلقائي", isOn: Binding(get: { d["ver"]["auto"].isTrue }, set: { v in Task { await setVer(auto: v, step: d["ver"]["step"].str) } })).font(.ox(15))
                    Picker("كل تعديل يزيد", selection: Binding(get: { d["ver"]["step"].string ?? "patch" }, set: { s in Task { await setVer(auto: d["ver"]["auto"].isTrue, step: s) } })) {
                        Text("الرقم الأخير (1.0.1)").tag("patch"); Text("الرقم الأوسط (1.1)").tag("minor"); Text("الرقم الأول (2.0)").tag("major")
                    }.font(.ox(15))
                    AsyncButton(action: { await backup() }) { Label("نزّل نسخة احتياطية", systemImage: "arrow.down.doc.fill") }
                } header: { Text("الإصدار والنسخ الاحتياطي") } footer: { Text("السيرفر ياخذ نسخة احتياطية يومية تلقائيًا لمخزن الملفات.").font(.ox(12)) }
            }
            Section("آخر أخطاء الموقع") {
                if errs.data["items"].arr.isEmpty { Text("ماكو أخطاء 👌").font(.ox(14)).foregroundStyle(t.mute) }
                ForEach(Array(errs.data["items"].arr.prefix(30).enumerated()), id: \.offset) { _, e in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e["msg"].str.isEmpty ? e["message"].str : e["msg"].str).font(.system(size: 12.5, design: .monospaced)).lineLimit(4).environment(\.layoutDirection, .leftToRight)
                        Text("\(e["path"].str) · \(Fmt.ago(e["at"].date))").font(.ox(11.5)).foregroundStyle(t.mute)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .oxScreen("حالة النظام", page: "system")
        .task { await r.load(); await errs.load(); await session.refreshStatus() }
        .refreshable { await r.load(); await errs.load() }
        .sheet(item: $share) { s in ShareSheet(items: [s.url]) }
    }
    func bot(_ name: String, _ b: JSON) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            InfoRow(title: name, value: b.isNull ? "—" : b["ok"].isTrue ? "مربوط ✓" : "مو مربوط", icon: "paperplane.fill", tone: b.isNull ? nil : b["ok"].isTrue ? "ok" : "bad")
            if (b["pending"].int ?? 0) > 0 { Text("رسائل معلّقة: \(Fmt.n(b["pending"]))").font(.ox(12)).foregroundStyle(prefs.theme.warn) }
            if !b["lastError"].str.isEmpty { Text(b["lastError"].str).font(.ox(12)).foregroundStyle(prefs.theme.bad).lineLimit(3) }
        }
    }
    func webhooks() async {
        do { let x = try await API.shared.post("/system/webhooks"); Toasts.shared.show("التحكم \(x["control"].isTrue ? "✓" : "✗") · الإشعارات \(x["notify"].isNull ? "—" : x["notify"].isTrue ? "✓" : "✗")"); await r.load() }
        catch { Toasts.shared.error(error) }
    }
    func setVer(auto: Bool, step: String) async {
        do { try await API.shared.post("/system/version", ["auto": .bool(auto), "step": .string(step.isEmpty ? "patch" : step), "date": true]); await r.load() }
        catch { Toasts.shared.error(error) }
    }
    func backup() async {
        do { share = ShareItem(url: try await API.shared.download(API.shared.url("/system/backup"))) } catch { Toasts.shared.error(error) }
    }
}

// MARK: - حسابي
struct AccountView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var ses = Remote("/me/sessions")
    @State private var cur = ""
    @State private var next = ""
    @State private var pinPw = ""
    @State private var pin = ""
    var body: some View {
        let t = prefs.theme
        Form {
            Section {
                InfoRow(title: "الاسم", value: session.name)
                InfoRow(title: "اسم المستخدم", value: "@" + session.me["username"].str)
                InfoRow(title: "الصلاحية", value: session.isOwner ? "المسؤول الرئيسي (كل شي)" : "\(Fmt.n(session.me["perms"].keys.count)) صلاحية")
            }
            Section {
                SecureField("كلمة السر الحالية", text: $cur).textContentType(.password)
                SecureField("كلمة السر الجديدة (8 أحرف أو أكثر)", text: $next).textContentType(.newPassword)
                AsyncButton(action: { await changePw() }) { Text("غيّر كلمة السر").font(.ox(15, .semibold)) }.disabled(cur.isEmpty || next.count < 8)
            } header: { Text("كلمة السر") } footer: { Text("لما تغيّرها تطلع كل الأجهزة الثانية تلقائيًا.").font(.ox(12)) }
            Section {
                HStack {
                    Text("الرمز السري").font(.ox(15))
                    Spacer()
                    Text(session.me["has_pin"].isTrue ? "محدد ✓" : "مو محدد").font(.ox(14)).foregroundStyle(session.me["has_pin"].isTrue ? t.ok : t.mute)
                }
                SecureField("كلمة السر للتأكيد", text: $pinPw)
                SecureField("رمز جديد (4 إلى 8 أرقام)", text: $pin).keyboardType(.numberPad)
                AsyncButton(action: { await setPin(clear: false) }) { Text("احفظ الرمز").font(.ox(15, .semibold)) }.disabled(pinPw.isEmpty || pin.count < 4)
                if session.me["has_pin"].isTrue { AsyncButton(role: .destructive, action: { await setPin(clear: true) }) { Text("شيل الرمز") }.disabled(pinPw.isEmpty) }
            } header: { Text("تأكيد الإجراءات الحساسة") } footer: { Text("إذا المسؤول فعّل عليك التأكيد، يطلب منك هذا الرمز (أو \(Guardian.shared.biometryName)) قبل الإجراءات الحساسة مثل الصيانة والحظر والإرسال الجماعي.").font(.ox(12)) }
            Section {
                ForEach(Array(ses.data["sessions"].arr.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 12) {
                        Image(systemName: s["client"].str == "app" ? "iphone" : "safari").foregroundStyle(t.accent).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(s["client"].str == "app" ? "تطبيق أورفيكس" : "المتصفح").font(.ox(14.5, .medium)); if s["current"].isTrue { Pill(text: "هذا الجهاز", tone: "ok") } }
                            Text("\(flag(s["country"].str)) \(s["ip"].str) · \(Fmt.ago(s["last_seen"].date))").font(.ox(12)).foregroundStyle(t.mute)
                        }
                    }
                    .swipeActions { if !s["current"].isTrue { Button(role: .destructive) { Task { try? await API.shared.post("/me/sessions/revoke", ["id": s["id"]]); await ses.load() } } label: { Label("طلّعه", systemImage: "xmark") } } }
                }
                AsyncButton(role: .destructive, action: { try? await API.shared.post("/me/sessions/revoke", ["all": true]); await ses.load(); Toasts.shared.show("طلعت كل الأجهزة الثانية") }) { Text("طلّع كل الأجهزة الثانية") }
            } header: { Text("الأجهزة المسجّلة") }
        }
        .formStyle(.grouped)
        .oxScreen("حسابي والأمان", page: "account")
        .task { await ses.load() }
    }
    func changePw() async {
        do { try await API.shared.post("/me/password", ["current": .string(cur), "next": .string(next)]); cur = ""; next = ""; Toasts.shared.show("تغيّرت كلمة السر ✓"); await ses.load() }
        catch { Toasts.shared.error(error) }
    }
    func setPin(clear: Bool) async {
        do {
            var b: JSON = ["password": .string(pinPw)]
            if clear { b["clear"] = true } else { b["pin"] = .string(pin) }
            let r = try await API.shared.post("/me/pin", b)
            Vault.set("pin", clear ? nil : pin)
            session.me["has_pin"] = r["has_pin"]
            pin = ""; pinPw = ""
            Toasts.shared.show(clear ? "انشال الرمز" : "انحفظ الرمز ✓ — راح يتأكد بـ\(Guardian.shared.biometryName) تلقائيًا")
        } catch { Toasts.shared.error(error) }
    }
}

// MARK: - حول
struct AboutView: View {
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(t.surface).frame(width: 120, height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(t.line))
                    OrvexSymbol(size: 66)
                }.padding(.top, 30)
                VStack(spacing: 8) {
                    OrvexWordmark(height: 20)
                    Text("POWERING POSSIBILITIES").font(.num(11, .medium)).tracking(3).foregroundStyle(t.mute)
                }
                Card {
                    InfoRow(title: "الإصدار", value: "\(Bundle.main.version) (\(Bundle.main.build))")
                    InfoRow(title: "السيرفر", value: API.shared.base.replacingOccurrences(of: "https://", with: ""))
                    InfoRow(title: "iOS", value: UIDevice.current.systemVersion)
                }
                VStack(spacing: 6) {
                    Text("تصميم وتطوير ياسين محمد").font(.ox(15, .semibold)).foregroundStyle(t.ink)
                    Text("ORVEX © \(Calendar.current.component(.year, from: Date()))").font(.num(12, .regular)).foregroundStyle(t.mute)
                }
            }.padding(16)
        }
        .background(t.bg)
        .oxScreen("حول أورفيكس", page: "about")
    }
}
