import SwiftUI

// MARK: - تبويب «الإدارة»
struct AdminView: View {
    @EnvironmentObject var session: Session
    @State private var askLogout = false
    var body: some View {
        let s = session.status
        Page(title: "الإدارة", intro: "المنتظرون، والفريق، وسجل كل ما تغيّر.", id: "admin") {
            Spacer().frame(height: 6)
            Card {
                NavRow(value: "settings", title: session.name, sub: "@\(session.me["username"].str) · \(session.isOwner ? "المسؤول الرئيسي" : "مشرف")", icon: "person.fill", color: "graphite")
                NavRow(value: "inbox", title: "الإشعارات", sub: "تنبيهات الفريق والتحديثات", icon: "bell.fill", color: "red", pill: session.unread > 0 ? (Fmt.n(session.unread), "bad") : nil)
            }
            if session.canAny(["waitlist.view", "waitlist.cast", "notify"]) {
                SectionTitle("المنتظرون والتذكير")
                Card {
                    if session.can("waitlist.view") { NavRow(value: "waitlist", title: "قائمة المنتظرين", sub: "البحث والتصدير والحذف", icon: "person.3.fill", color: "blue", trailing: s["waitlist"].isNull ? nil : Fmt.n(s["waitlist"])) }
                    if session.can("waitlist.cast") { NavRow(value: "cast", title: "إرسال تذكير", sub: "رسالة الفتح أو رسالة مخصّصة", icon: "paperplane.fill", color: "green") }
                    if session.can("waitlist.view") { NavRow(value: "casts", title: "الرسائل المرسلة", sub: "عدد من وصلتهم ومن ضغط على الرابط", icon: "chart.bar.doc.horizontal", color: "teal") }
                    if session.can("notify") { NavRow(value: "bot", title: "رسائل بوت التذكير", sub: "نصوص البوت وأزراره", icon: "text.bubble.fill", color: "indigo") }
                }
            }
            if session.isOwner || session.canAny(["history.view", "log.view", "monitor"]) {
                SectionTitle("الفريق والسجل")
                Card {
                    if session.isOwner || session.can("monitor") { NavRow(value: "users", title: "المشرفون والصلاحيات", sub: "الحسابات، ومن المتصل الآن", icon: "person.2.badge.gearshape.fill", color: "purple") }
                    if session.can("history.view") { NavRow(value: "history", title: "سجل التعديلات", sub: "من غيّر ماذا ومتى، مع التراجع", icon: "clock.arrow.circlepath", color: "amber") }
                    if session.can("log.view") { NavRow(value: "log", title: "سجل الدخول والنشاط", sub: "عمليات الدخول وكل الإجراءات", icon: "list.bullet.rectangle.portrait.fill", color: "steel") }
                    if session.can("app.notify") { NavRow(value: "notify-send", title: "إرسال إشعار للفريق", sub: "يظهر داخل تطبيق المشرفين", icon: "megaphone.fill", color: "orange") }
                }
            }
            if session.canAny(["files.view", "app.updates", "app.control"]) {
                SectionTitle("الملفات والتطبيق")
                Card {
                    if session.can("files.view") { NavRow(value: "files", title: "الملفات", sub: "رفع الصور والملفات والحصول على روابطها", icon: "folder.fill", color: "teal") }
                    if session.can("app.updates") { NavRow(value: "app-updates", title: "تحديثات التطبيق", sub: "نشر إصدار جديد للمشرفين", icon: "arrow.down.app.fill", color: "graphite", trailing: Bundle.main.version) }
                    if session.can("app.control") { NavRow(value: "app-control", title: "التحكم بالتطبيق", sub: "إيقاف التطبيق ومظهره الافتراضي", icon: "switch.2", color: "red") }
                }
            }
            SectionTitle("النظام والحساب")
            Card {
                if session.can("system") { NavRow(value: "system", title: "حالة النظام", sub: "الخدمات، والبوتات، والنسخ الاحتياطي", icon: "server.rack", color: "steel") }
                NavRow(value: "settings", title: "الإعدادات", sub: "المظهر، وكلمة المرور، والأجهزة", icon: "gearshape.fill", color: "graphite")
                NavRow(value: "about", title: "حول التطبيق", icon: "info.circle.fill", color: "blue")
            }
            Spacer().frame(height: 18)
            Card { ActionRow(title: "تسجيل الخروج", icon: "rectangle.portrait.and.arrow.right", tone: "bad") { askLogout = true } }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: "search") { Image(systemName: "magnifyingglass") }.accessibilityLabel("البحث") } }
        .refreshable { await session.refreshStatus() }
        .confirmationDialog("تسجيل الخروج من التطبيق؟", isPresented: $askLogout, titleVisibility: .visible) {
            Button("تسجيل الخروج", role: .destructive) { Task { await session.logout() } }
        }
    }
}

// MARK: - قائمة المنتظرين
struct WaitlistView: View {
    @EnvironmentObject var session: Session
    @StateObject private var r = Remote("/waitlist")
    @State private var q = ""
    @State private var share: ShareItem?
    @State private var clearAsk = false
    @State private var clearWord = ""
    @State private var removeOne: JSON? = nil
    var items: [JSON] {
        let all = Array(r.data["items"].arr.reversed())
        guard !q.isEmpty else { return all }
        return all.filter { $0["name"].str.localizedCaseInsensitiveContains(q) || $0["username"].str.localizedCaseInsensitiveContains(q) || $0["id"].str.contains(q) }
    }
    var body: some View {
        Page(title: "قائمة المنتظرين", intro: "من سجّلوا في بوت التذكير ليصلهم إشعار فتح الاشتراكات.", id: "waitlist") {
            RemoteBody(r: r) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 6)
                    KPIGrid {
                        KPI(title: "عدد المنتظرين", value: Fmt.n(r.data["count"]))
                        KPI(title: "البوت", value: r.data["handle"].str.isEmpty ? "—" : "@" + r.data["handle"].str.trimmingCharacters(in: CharacterSet(charactersIn: "@")))
                    }
                    if session.can("waitlist.manage") {
                        Spacer().frame(height: 12)
                        HStack(spacing: 10) {
                            smallButton("تصدير الأسماء", "square.and.arrow.up") { await export() }
                            smallButton("مسح القائمة", "trash", tone: "bad") { clearWord = ""; clearAsk = true }
                        }.padding(.horizontal, 16)
                    }
                    SectionTitle(items.isEmpty ? (q.isEmpty ? "القائمة فارغة" : "لا توجد نتائج") : "الأحدث أولًا", trailing: q.isEmpty ? nil : Fmt.n(items.count))
                    if !items.isEmpty {
                        Card {
                            ForEach(Array(items.prefix(300).enumerated()), id: \.offset) { _, it in
                                HStack(spacing: 12) {
                                    Text(String(it["name"].str.prefix(1))).font(.ox(15, .semibold)).foregroundStyle(C.ink).frame(width: 36, height: 36).background(C.fill, in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(it["name"].str.isEmpty ? "بلا اسم" : it["name"].str).font(.ox(15)).foregroundStyle(C.ink)
                                        Text(it["username"].str.isEmpty ? "المعرّف \(it["id"].str)" : "@" + it["username"].str).font(.ox(12)).foregroundStyle(C.mute)
                                    }
                                    Spacer()
                                    Text(Fmt.ago(it["at"].date)).font(.ox(11.5)).foregroundStyle(C.mute)
                                    if session.can("waitlist.manage") {
                                        Menu {
                                            Button(role: .destructive) { removeOne = it } label: { Label("حذف من القائمة", systemImage: "trash") }
                                        } label: { Image(systemName: "ellipsis").foregroundStyle(C.mute).frame(width: 30, height: 30) }
                                    }
                                }.padding(.horizontal, 14).padding(.vertical, 9)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $q, prompt: "ابحث بالاسم أو المعرّف")
        .task { await r.load() }
        .refreshable { await r.load() }
        .sheet(item: $share) { s in ShareSheet(items: [s.url]) }
        .confirmationDialog("حذف «\(removeOne?["name"].str ?? "")» من القائمة؟", isPresented: Binding(get: { removeOne != nil }, set: { if !$0 { removeOne = nil } }), titleVisibility: .visible) {
            Button("حذف", role: .destructive) { if let it = removeOne { Task { await remove([it["id"].str]) } } }
        }
        .alert("مسح قائمة المنتظرين", isPresented: $clearAsk) {
            TextField("اكتب: مسح", text: $clearWord)
            Button("إلغاء", role: .cancel) {}
            Button("مسح الجميع", role: .destructive) { Task { await clear() } }
        } message: { Text("سيُحذف \(Fmt.n(r.data["count"])) شخصًا نهائيًا. اكتب كلمة «مسح» للتأكيد.") }
    }
    func smallButton(_ t: String, _ i: String, tone: String? = nil, _ a: @escaping () async -> Void) -> some View {
        Button { Task { await a() } } label: {
            Label(t, systemImage: i).font(.ox(14, .medium)).foregroundStyle(tone == nil ? C.ink : C.tone(tone))
                .frame(maxWidth: .infinity).frame(height: 46).background(C.card, in: Capsule())
        }.buttonStyle(.plain)
    }
    func remove(_ ids: [String]) async {
        do { try await API.shared.post("/waitlist/remove", ["ids": .array(ids.map { .string($0) })]); Toasts.shared.show("حُذف من القائمة."); await r.load(); await session.refreshStatus() }
        catch { Toasts.shared.error(error) }
    }
    func clear() async {
        guard clearWord.trimmingCharacters(in: .whitespaces) == "مسح" else { Toasts.shared.show("لم يُمسح شيء: كلمة التأكيد غير صحيحة.", "warn"); return }
        do { let x = try await API.shared.post("/waitlist/clear", ["confirm": "مسح"]); Toasts.shared.show("مُسحت القائمة (\(Fmt.n(x["removed"])))."); await r.load(); await session.refreshStatus() }
        catch { Toasts.shared.error(error) }
    }
    func export() async {
        do { share = ShareItem(url: try await API.shared.download(API.shared.url("/waitlist/export"))) } catch { Toasts.shared.error(error) }
    }
}

// MARK: - إرسال تذكير
struct CastComposeView: View {
    @EnvironmentObject var session: Session
    @StateObject private var preview = Remote("/tg/preview")
    @State private var kind = "open"
    @State private var text = ""
    @State private var keep = true
    @State private var job: JSON = .null
    @State private var running = false
    @State private var askStart = false
    @State private var stopFlag = false
    var count: Int { session.status["waitlist"].int ?? 0 }
    var body: some View {
        Page(title: "إرسال تذكير", intro: "تُرسل الرسالة عبر بوت التيليجرام إلى كل المنتظرين، على دفعات حتى تصل إلى الجميع.", id: "cast") {
            Picker("", selection: $kind) { Text("رسالة الفتح").tag("open"); Text("رسالة مخصّصة").tag("custom") }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 8)
            if kind == "custom" {
                SectionTitle("نص الرسالة")
                Card { TextBlock(title: "يمكن استخدام <b>عريض</b> و<i>مائل</i> والروابط", text: $text, multiline: true) }
            } else {
                Spacer().frame(height: 12)
                Card { ToggleRow(title: "إبقاؤهم في القائمة بعد الإرسال", sub: keep ? "يمكنك تذكيرهم مرة أخرى لاحقًا" : "يُحذفون من القائمة بعد وصول الرسالة", isOn: $keep) }
                SectionFooter("نص رسالة الفتح يُعدَّل من «رسائل بوت التذكير». يُستبدل رابط الاشتراك برابط يتتبّع عدد النقرات.")
            }
            SectionTitle("المعاينة")
            let html = kind == "open" ? preview.data["open"].str : text
            MessageBubble(html: html.isEmpty ? "…" : html)
            if !job.isNull { SectionTitle(running ? "جارٍ الإرسال" : "آخر إرسال"); Card(padded: true) { CastProgress(job: job) } }
            Spacer().frame(height: 18)
            if running {
                PrimaryButton(title: "إيقاف الإرسال", icon: "stop.fill", tone: "bad") { stopFlag = true }
            } else {
                PrimaryButton(title: count == 1 ? "إرسال إلى شخص واحد" : "إرسال إلى \(Fmt.n(count)) شخص", icon: "paperplane.fill", disabled: count == 0 || (kind == "custom" && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) { askStart = true }
            }
        }
        .task { await preview.load(); await session.refreshStatus() }
        .confirmationDialog("إرسال الرسالة إلى \(Fmt.n(count)) شخص؟", isPresented: $askStart, titleVisibility: .visible) {
            Button("إرسال") { Task { await start() } }
        }
    }
    func start() async {
        do {
            var b: JSON = ["kind": .string(kind), "keep": .bool(kind == "custom" ? true : keep)]
            if kind == "custom" { b["text"] = .string(text) }
            let r = try await API.shared.post("/waitlist/cast/start", b)
            job = r["job"]
            await loop()
        } catch let e as APIError where e.status == 409 {
            if let id = e.data["job"].string { job = ["id": .string(id), "status": "running"]; Toasts.shared.show("يوجد إرسال قيد التنفيذ، وسيُستكمل الآن.", "warn"); await loop() }
            else { Toasts.shared.error(e) }
        } catch { Toasts.shared.error(error) }
    }
    func loop() async {
        running = true; stopFlag = false
        defer { running = false; Task { await session.refreshStatus() } }
        while !stopFlag {
            do {
                let r = try await API.shared.post("/waitlist/cast/step", ["id": .string(job["id"].str)])
                withAnimation(.snappy) { job = r["job"] }
                if (r["pending"].int ?? 0) == 0 || job["status"].str != "running" {
                    Toasts.shared.show("اكتمل الإرسال: وصلت إلى \(Fmt.n(job["sent"])) وتعذّرت \(Fmt.n(job["failed"])).")
                    return
                }
                if let w = r["wait"].double, w > 0 { try? await Task.sleep(nanoseconds: UInt64(w * 1e9)) }
            } catch { Toasts.shared.error(error); return }
        }
        _ = try? await API.shared.post("/waitlist/cast/stop", ["id": .string(job["id"].str)])
        Toasts.shared.show("أُوقف الإرسال.", "warn")
    }
}

struct CastProgress: View {
    let job: JSON
    var body: some View {
        let total = max(1, job["total"].double ?? 1), sent = job["sent"].double ?? 0, failed = job["failed"].double ?? 0
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Fmt.percent((sent + failed) / total)).font(.num(22)).foregroundStyle(C.ink)
                Spacer()
                Text("من \(Fmt.n(total))").font(.ox(13)).foregroundStyle(C.mute)
            }
            ProgressView(value: min(1, (sent + failed) / total)).tint(C.ok)
            HStack(spacing: 16) {
                Label("وصلت: \(Fmt.n(sent))", systemImage: "checkmark.circle.fill").foregroundStyle(C.ok)
                if failed > 0 { Label("تعذّرت: \(Fmt.n(failed))", systemImage: "xmark.circle.fill").foregroundStyle(C.bad) }
                if (job["clicks"].double ?? 0) > 0 { Label("نقرات: \(Fmt.n(job["clicks"]))", systemImage: "hand.tap.fill").foregroundStyle(C.info) }
            }.font(.ox(12.5))
        }
    }
}

// MARK: - الرسائل المرسلة
struct CastsView: View {
    @StateObject private var r = Remote("/waitlist/casts")
    var body: some View {
        Page(title: "الرسائل المرسلة", intro: "كل رسالة أُرسلت للمنتظرين، ومن وصلتهم، ومن ضغط على الرابط.", id: "casts") {
            RemoteBody(r: r) {
                if r.data["items"].arr.isEmpty { EmptyState(icon: "paperplane", title: "لم تُرسل أي رسالة بعد") }
                else {
                    Spacer().frame(height: 10)
                    Card {
                        ForEach(Array(r.data["items"].arr.enumerated()), id: \.offset) { _, c in
                            NavigationLink(value: CastRoute(id: c["id"].str)) {
                                RowContent(title: c["kind"].str == "open" ? "رسالة الفتح" : "رسالة مخصّصة",
                                           sub: "\(Fmt.date(c["at"].date)) · وصلت \(Fmt.n(c["sent"])) من \(Fmt.n(c["total"])) · \(Fmt.n(c["clicks"])) نقرة",
                                           pill: c["status"].str == "running" ? ("قيد الإرسال", "info") : c["status"].str == "stopped" ? ("أُوقفت", "warn") : ("اكتملت", "ok"))
                            }.buttonStyle(RowPress())
                        }
                    }
                }
            }
        }
        .task { await r.load() }
        .refreshable { await r.load() }
    }
}

struct CastDetailView: View {
    let id: String
    @StateObject private var r: Remote
    @State private var filter = "all"
    init(id: String) { self.id = id; _r = StateObject(wrappedValue: Remote("/waitlist/cast/\(id)")) }
    var body: some View {
        let j = r.data["job"]
        Page(title: j["kind"].str == "open" ? "رسالة الفتح" : "رسالة مخصّصة", intro: Fmt.date(j["at"].date), id: "casts") {
            RemoteBody(r: r) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 6)
                    Card(padded: true) { CastProgress(job: j) }
                    SectionTitle("الرسالة")
                    MessageBubble(html: j["text"].str)
                    SectionTitle("المستلمون")
                    Picker("", selection: $filter) { Text("الكل").tag("all"); Text("وصلت").tag("sent"); Text("تعذّرت").tag("failed"); Text("بالانتظار").tag("pending") }
                        .pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 10)
                    Card {
                        let rows = r.data["rows"].arr.filter { filter == "all" || $0["status"].str == filter }
                        if rows.isEmpty { Text("لا يوجد.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                        ForEach(Array(rows.prefix(300).enumerated()), id: \.offset) { _, x in
                            HStack(spacing: 10) {
                                Image(systemName: x["status"].str == "sent" ? "checkmark.circle.fill" : x["status"].str == "failed" ? "xmark.circle.fill" : "clock")
                                    .foregroundStyle(x["status"].str == "sent" ? C.ok : x["status"].str == "failed" ? C.bad : C.mute)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(x["name"].str.isEmpty ? "بلا اسم" : x["name"].str).font(.ox(14.5)).foregroundStyle(C.ink)
                                    if !x["err"].str.isEmpty { Text(x["err"].str).font(.ox(11.5)).foregroundStyle(C.bad).lineLimit(2) }
                                }
                                Spacer()
                            }.padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }
                }
            }
        }
        .task { await r.load() }
    }
}

/// فقاعة رسالة تيليجرام للمعاينة
struct MessageBubble: View {
    var html: String
    @Environment(\.colorScheme) var scheme
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(html.tgAttributed).foregroundStyle(scheme == .dark ? Color.white : Color.black).lineSpacing(2)
            }
            .padding(12)
            .background(scheme == .dark ? Color(hex: 0x182533) : Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous))
            Spacer(minLength: 30)
        }
        .padding(12)
        .background(scheme == .dark ? Color(hex: 0x0E1621) : Color(hex: 0xD5E4C8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
struct ShareItem: Identifiable { let id = UUID(); let url: URL }

extension String {
    /// تحويل HTML تيليجرام لنص عادي للمعاينة
    var tgPlain: String {
        var s = self.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (a, b) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] { s = s.replacingOccurrences(of: a, with: b) }
        return s
    }
    /// HTML تيليجرام ← AttributedString (عريض، مائل، روابط)
    var tgAttributed: AttributedString {
        var out = AttributedString()
        var bold = 0, italic = 0, code = 0
        var link: URL? = nil
        let scanner = self.replacingOccurrences(of: "\r", with: "")
        var i = scanner.startIndex
        var buf = ""
        func flush() {
            guard !buf.isEmpty else { return }
            var a = AttributedString(buf.tgPlain)
            var f = Font.ox(15, bold > 0 ? .bold : .regular)
            if italic > 0 { f = f.italic() }
            if code > 0 { f = .system(size: 14, design: .monospaced) }
            a.font = f
            if let l = link { a.link = l; a.underlineStyle = .single }
            out += a; buf = ""
        }
        while i < scanner.endIndex {
            if scanner[i] == "<", let close = scanner[i...].firstIndex(of: ">") {
                let tag = String(scanner[scanner.index(after: i)..<close]).lowercased()
                flush()
                switch tag {
                case "b", "strong": bold += 1
                case "/b", "/strong": bold = max(0, bold - 1)
                case "i", "em": italic += 1
                case "/i", "/em": italic = max(0, italic - 1)
                case "code", "pre": code += 1
                case "/code", "/pre": code = max(0, code - 1)
                case "/a": link = nil
                default:
                    if tag.hasPrefix("a "), let r = tag.range(of: "href=\"([^\"]+)\"", options: .regularExpression) {
                        let h = String(String(scanner[scanner.index(after: i)..<close])[r]).replacingOccurrences(of: "href=", with: "", options: .caseInsensitive).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        link = URL(string: h.replacingOccurrences(of: "&amp;", with: "&"))
                    } else if tag.hasPrefix("br") { buf += "\n" }
                }
                i = scanner.index(after: close)
            } else { buf.append(scanner[i]); i = scanner.index(after: i) }
        }
        flush()
        return out
    }
}

/// معاينة حيّة لرسالة الفتح أثناء تعديلها
struct BotOpenPreview: View {
    var base: [Seg]
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let n = store.v(base)
        let parts = [n["openIntro"].ar, n["openMessage"].ar, n["openCta"].ar.isEmpty ? "" : "<a href=\"https://iraqfit.com\">" + n["openCta"].ar + "</a>", n["openFooter"].ar].filter { !$0.isEmpty }
        MessageBubble(html: parts.joined(separator: "\n\n"))
    }
}
