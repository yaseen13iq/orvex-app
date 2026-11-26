import SwiftUI
import Charts

// MARK: - التيليجرام (الرئيسية)
struct TelegramView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/tg/stats?days=30")
    var body: some View {
        let t = prefs.theme
        ScrollView {
            VStack(spacing: 14) {
                if session.can("waitlist.view") {
                    RemoteBody(r: r) {
                        VStack(spacing: 14) {
                            if !r.data["bot"].isTrue {
                                Label("بوت الإشعارات مو مربوط (NOTIFY_BOT_TOKEN ناقص)", systemImage: "exclamationmark.triangle.fill").font(.ox(13.5)).foregroundStyle(t.warn)
                                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(t.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                            }
                            KPIGrid {
                                KPI(title: "المنتظرين هسه", value: Fmt.n(r.data["count"]), icon: "person.3.fill")
                                KPI(title: "سجّلوا (30 يوم)", value: Fmt.n(sum("join")), icon: "person.badge.plus", tone: "ok")
                                KPI(title: "شطبوا (30 يوم)", value: Fmt.n(sum("leave")), icon: "person.badge.minus", tone: "bad")
                                KPI(title: "ضغطوا «ذكّرني»", value: Fmt.n(sum("rem")), icon: "bell.fill")
                            }
                            joinsChart
                            castsCard
                        }
                    }
                }
                actions
            }.padding(16)
        }
        .background(t.bg)
        .oxScreen("التيليجرام", page: "telegram")
        .task { if session.can("waitlist.view") { await r.load() } }
        .refreshable { await r.load() }
    }
    func sum(_ k: String) -> Double { r.data["perDay"].object?.pairs.reduce(0) { $0 + ($1.1[k].double ?? 0) } ?? 0 }

    var actions: some View {
        Card(title: "الإجراءات", icon: "bolt.fill") {
            VStack(spacing: 0) {
                if session.can("waitlist.cast") { link("cast", "أرسل التذكير هسه", "paperplane.fill", "رسالة الفتح أو رسالة حرة، على دفعات") }
                if session.can("waitlist.view") { link("waitlist", "قائمة المنتظرين", "list.bullet", "بحث، حذف، تصدير، مسح") }
                if session.can("notify") { link("botmsgs", "رسائل البوت", "text.bubble.fill", "عدّل كل رسالة وشوف معاينتها") }
            }
        }
    }
    func link(_ id: String, _ title: String, _ icon: String, _ sub: String) -> some View {
        NavigationLink(value: id) {
            HStack { RowLabel(title: title, icon: icon, sub: sub); Image(systemName: "chevron.left").font(.system(size: 12)).foregroundStyle(prefs.theme.mute) }.padding(.vertical, 6)
        }.buttonStyle(.plain).accessibilityIdentifier("tg-\(id)")
    }

    struct DP: Identifiable { var id: String { "\(day.timeIntervalSince1970)-\(k)" }; let day: Date; let k: String; let v: Double }
    var joinsChart: some View {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var pts: [DP] = []
        for (d, v) in r.data["perDay"].object?.pairs ?? [] {
            guard let dt = f.date(from: d) else { continue }
            pts.append(DP(day: dt, k: "سجّلوا", v: v["join"].double ?? 0))
            pts.append(DP(day: dt, k: "شطبوا", v: -(v["leave"].double ?? 0)))
        }
        return Card(title: "التسجيل والشطب", icon: "chart.bar.fill", subtitle: "آخر 30 يوم") {
            if pts.isEmpty { Text("ماكو حركة بعد").font(.ox(13)).foregroundStyle(prefs.theme.mute) }
            else {
                Chart(pts) { p in
                    BarMark(x: .value("اليوم", p.day, unit: .day), y: .value("العدد", p.v)).foregroundStyle(by: .value("النوع", p.k))
                }
                .chartForegroundStyleScale(["سجّلوا": prefs.theme.ok, "شطبوا": prefs.theme.bad])
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 170)
            }
        }
    }
    var castsCard: some View {
        let casts = r.data["casts"].arr
        return Card(title: "الرسائل الجماعية", icon: "paperplane.circle.fill", subtitle: "التوصيل والضغطات على الرابط") {
            if casts.isEmpty { Text("ما انرسلت رسائل بعد").font(.ox(13)).foregroundStyle(prefs.theme.mute) }
            ForEach(Array(casts.prefix(8).enumerated()), id: \.offset) { _, c in
                NavigationLink(value: CastRoute(id: c["id"].str)) { CastRow(c: c) }.buttonStyle(.plain)
                Divider().opacity(0.4)
            }
        }
    }
}

struct CastRow: View {
    let c: JSON
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme, total = max(1, c["total"].double ?? 1), sent = c["sent"].double ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(c["kind"].str == "open" ? "رسالة الفتح" : "رسالة حرة").font(.ox(14.5, .semibold)).foregroundStyle(t.ink)
                Pill(text: statusName(c["status"].str), tone: c["status"].str == "done" ? "ok" : c["status"].str == "running" ? "info" : "warn")
                Spacer()
                Text(Fmt.ago(c["at"].date)).font(.ox(12)).foregroundStyle(t.mute)
            }
            ProgressView(value: min(1, (sent + (c["failed"].double ?? 0)) / total)).tint(t.ok)
            HStack(spacing: 14) {
                Label("\(Fmt.n(sent)) وصل", systemImage: "checkmark").foregroundStyle(t.ok)
                if (c["failed"].double ?? 0) > 0 { Label("\(Fmt.n(c["failed"])) فشل", systemImage: "xmark").foregroundStyle(t.bad) }
                Label("\(Fmt.n(c["clicks"])) ضغط الرابط", systemImage: "hand.tap").foregroundStyle(t.info)
                Spacer()
                Text("من \(Fmt.n(total))").foregroundStyle(t.mute)
            }.font(.ox(12))
        }.padding(.vertical, 4)
    }
    func statusName(_ s: String) -> String { ["done": "خلص", "running": "شغّال", "stopped": "توقف"][s] ?? s }
}

// MARK: - قائمة المنتظرين
struct WaitlistView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/waitlist")
    @State private var q = ""
    @State private var selection = Set<String>()
    @State private var editMode: EditMode = .inactive
    @State private var share: ShareItem?
    @State private var clearAsk = false
    @State private var clearWord = ""
    var items: [JSON] {
        let all = r.data["items"].arr
        guard q.count >= 1 else { return all.reversed() }
        return all.reversed().filter { $0["name"].str.localizedCaseInsensitiveContains(q) || $0["username"].str.localizedCaseInsensitiveContains(q) || $0["id"].str.contains(q) }
    }
    var body: some View {
        let t = prefs.theme
        List(selection: $selection) {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("المنتظرين").font(.ox(13)).foregroundStyle(t.mute)
                        Text(Fmt.n(r.data["count"])).font(.num(34, .bold)).accessibilityIdentifier("waitCount")
                    }
                    Spacer()
                    if !r.data["handle"].str.isEmpty { Text("@" + r.data["handle"].str.trimmingCharacters(in: CharacterSet(charactersIn: "@"))).font(.num(13, .regular)).foregroundStyle(t.mute) }
                }
            }
            Section {
                if r.loaded && items.isEmpty { Text(q.isEmpty ? "القائمة فاضية" : "ماكو نتائج").font(.ox(14)).foregroundStyle(t.mute) }
                ForEach(items, id: \.self) { it in
                    HStack(spacing: 12) {
                        Text(String(it["name"].str.prefix(1))).font(.ox(15, .bold)).frame(width: 36, height: 36).background(t.surface2, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(it["name"].str.isEmpty ? "بدون اسم" : it["name"].str).font(.ox(15))
                            Text(it["username"].str.isEmpty ? it["id"].str : "@" + it["username"].str).font(.num(12, .regular)).foregroundStyle(t.mute)
                        }
                        Spacer()
                        Text(Fmt.ago(it["at"].date)).font(.ox(11.5)).foregroundStyle(t.mute)
                    }
                    .tag(it["id"].str)
                    .swipeActions {
                        if session.can("waitlist.manage") {
                            Button(role: .destructive) { Task { await remove([it["id"].str]) } } label: { Label("حذف", systemImage: "trash") }
                        }
                    }
                }
            } header: { Text("الأحدث أولًا") }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .searchable(text: $q, prompt: "ابحث بالاسم أو المعرّف")
        .oxScreen("قائمة المنتظرين", page: "waitlist")
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .task { await r.load() }
        .refreshable { await r.load() }
        .toolbar {
            if session.can("waitlist.manage") {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { Task { await export() } } label: { Label("تصدير CSV", systemImage: "square.and.arrow.up") }
                        Button { withAnimation { editMode = editMode == .active ? .inactive : .active; selection = [] } } label: { Label(editMode == .active ? "إلغاء التحديد" : "تحديد وحذف", systemImage: "checkmark.circle") }
                        Divider()
                        Button(role: .destructive) { clearWord = ""; clearAsk = true } label: { Label("مسح القائمة كلها", systemImage: "trash.fill") }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityIdentifier("waitMenu")
                }
            }
            if editMode == .active && !selection.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) { Task { await remove(Array(selection)); editMode = .inactive } } label: { Label("احذف \(Fmt.n(selection.count))", systemImage: "trash") }
                }
            }
        }
        .sheet(item: $share) { s in ShareSheet(items: [s.url]) }
        .alert("مسح كل المنتظرين", isPresented: $clearAsk) {
            TextField("اكتب: مسح", text: $clearWord)
            Button("إلغاء", role: .cancel) {}
            Button("امسح الكل", role: .destructive) { Task { await clear() } }.disabled(clearWord.trimmingCharacters(in: .whitespaces) != "مسح")
        } message: { Text("راح ينمسح \(Fmt.n(r.data["count"])) شخص وما يرجعون. اكتب كلمة «مسح» للتأكيد.") }
    }
    func remove(_ ids: [String]) async {
        do { try await API.shared.post("/waitlist/remove", ["ids": .array(ids.map { .string($0) })]); Toasts.shared.show("انحذف \(Fmt.n(ids.count))"); await r.load() }
        catch { Toasts.shared.error(error) }
    }
    func clear() async {
        do { let x = try await API.shared.post("/waitlist/clear", ["confirm": "مسح"]); Toasts.shared.show("انمسح \(Fmt.n(x["removed"]))"); await r.load() }
        catch { Toasts.shared.error(error) }
    }
    func export() async {
        do { let u = try await API.shared.download(API.shared.url("/waitlist/export")); share = ShareItem(url: u) }
        catch { Toasts.shared.error(error) }
    }
}

// MARK: - إرسال التذكير
struct CastComposeView: View {
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var preview = Remote("/tg/preview")
    @StateObject private var wl = Remote("/tg/stats?days=7")
    @State private var kind = "open"
    @State private var text = ""
    @State private var keep = true
    @State private var job: JSON = .null
    @State private var running = false
    @State private var askStart = false
    @State private var stopFlag = false

    var body: some View {
        let t = prefs.theme
        Form {
            Section {
                Picker("", selection: $kind) { Text("رسالة الفتح").tag("open"); Text("رسالة حرة").tag("custom") }.pickerStyle(.segmented)
                if kind == "custom" {
                    TextField("اكتب الرسالة… (يدعم <b>عريض</b> و<a href=\"…\">روابط</a>)", text: $text, axis: .vertical).font(.ox(15)).lineLimit(5...14)
                } else {
                    Toggle(isOn: $keep) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("يبقون بالقائمة بعد الإرسال").font(.ox(15))
                            Text(keep ? "تكدر ترسل لهم مرة ثانية" : "ينشطبون تلقائيًا بعد ما توصلهم").font(.ox(12)).foregroundStyle(t.mute)
                        }
                    }
                }
            } header: { Text("نوع الرسالة") } footer: {
                if kind == "open" { Text("نص رسالة الفتح من «رسائل البوت». رابط الاشتراك يتحوّل لرابط متتبَّع حتى تعرف منو ضغط.").font(.ox(12)) }
            }
            Section("المعاينة") {
                let html = kind == "open" ? preview.data["open"].str : text
                if html.isEmpty { Text("…").foregroundStyle(t.mute) } else { TGBubble(html: html).listRowInsets(EdgeInsets()) }
            }
            Section {
                if !job.isNull { CastProgress(job: job, running: running) }
                if running {
                    Button(role: .destructive) { stopFlag = true } label: { Label("أوقف الإرسال", systemImage: "stop.fill") }
                } else {
                    Button { askStart = true } label: {
                        Label("أرسل لـ \(Fmt.n(wl.data["count"])) شخص", systemImage: "paperplane.fill").font(.ox(16, .semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.oxProminent).listRowBackground(Color.clear)
                    .disabled((wl.data["count"].int ?? 0) == 0 || (kind == "custom" && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .accessibilityIdentifier("castSend")
                }
            } footer: { Text("يرسل 30 رسالة كل دفعة مع احترام حدود تيليجرام. إذا سدّيت التطبيق، السيرفر يكمّل لوحده كل دقيقة (لازم Cron مفعّل).").font(.ox(12)) }
        }
        .formStyle(.grouped)
        .oxScreen("أرسل التذكير", page: "cast")
        .task { await preview.load(); await wl.load() }
        .confirmationDialog("ترسل الرسالة لـ \(Fmt.n(wl.data["count"])) شخص؟", isPresented: $askStart, titleVisibility: .visible) {
            Button("إي، أرسل") { Task { await start() } }
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
            if let id = e.data["job"].string { job = ["id": .string(id), "status": "running"]; Toasts.shared.show("فيه إرسال شغّال — راح أكمّله", "warn"); await loop() }
            else { Toasts.shared.error(e) }
        } catch { Toasts.shared.error(error) }
    }
    func loop() async {
        running = true; stopFlag = false
        LiveCenter.shared.sync(with: Session.shared.status)
        defer { running = false; Task { await Session.shared.refreshStatus() } }
        while !stopFlag {
            do {
                let r = try await API.shared.post("/waitlist/cast/step", ["id": .string(job["id"].str)])
                withAnimation(.snappy) { job = r["job"] }
                if (r["pending"].int ?? 0) == 0 || job["status"].str != "running" {
                    Prefs.shared.notify(.success)
                    Toasts.shared.show("خلص الإرسال: وصل \(Fmt.n(job["sent"])) · فشل \(Fmt.n(job["failed"]))")
                    return
                }
                if let w = r["wait"].double, w > 0 { try? await Task.sleep(nanoseconds: UInt64(w * 1e9)) }
            } catch { Toasts.shared.error(error); return }
        }
        _ = try? await API.shared.post("/waitlist/cast/stop", ["id": .string(job["id"].str)])
        Toasts.shared.show("توقف الإرسال", "warn")
    }
}
struct CastProgress: View {
    let job: JSON
    let running: Bool
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let total = max(1, job["total"].double ?? 1), sent = job["sent"].double ?? 0, failed = job["failed"].double ?? 0
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(running ? "جاري الإرسال…" : "آخر إرسال").font(.ox(15, .semibold))
                Spacer()
                Text("\(Int((sent + failed) / total * 100))%").font(.num(18, .bold)).contentTransition(.numericText())
            }
            ProgressView(value: (sent + failed) / total).tint(prefs.theme.ok)
            HStack {
                Label("\(Fmt.n(sent)) وصل", systemImage: "checkmark.circle.fill").foregroundStyle(prefs.theme.ok)
                Spacer()
                Label("\(Fmt.n(failed)) فشل", systemImage: "xmark.circle.fill").foregroundStyle(failed > 0 ? prefs.theme.bad : prefs.theme.mute)
                Spacer()
                Text("من \(Fmt.n(total))").foregroundStyle(prefs.theme.mute)
            }.font(.ox(13))
        }.padding(.vertical, 6)
    }
}

// MARK: - تفاصيل إرسال
struct CastDetailView: View {
    let id: String
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r: Remote
    @State private var filter = "all"
    init(id: String) { self.id = id; _r = StateObject(wrappedValue: Remote("/waitlist/cast/\(id)")) }
    var body: some View {
        let t = prefs.theme, j = r.data["job"]
        List {
            Section { CastRow(c: j) }
            Section("الرسالة") { TGBubble(html: j["text"].str).listRowInsets(EdgeInsets()) }
            Section {
                Picker("", selection: $filter) { Text("الكل").tag("all"); Text("وصل").tag("sent"); Text("فشل").tag("failed"); Text("بالانتظار").tag("pending") }.pickerStyle(.segmented)
                ForEach(Array(r.data["rows"].arr.filter { filter == "all" || $0["status"].str == filter }.prefix(500).enumerated()), id: \.offset) { _, x in
                    HStack {
                        Image(systemName: x["status"].str == "sent" ? "checkmark.circle.fill" : x["status"].str == "failed" ? "xmark.circle.fill" : "clock").foregroundStyle(x["status"].str == "sent" ? t.ok : x["status"].str == "failed" ? t.bad : t.mute)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(x["name"].str).font(.ox(14.5))
                            if !x["err"].str.isEmpty { Text(x["err"].str).font(.ox(12)).foregroundStyle(t.bad) }
                        }
                        Spacer()
                        Text(Fmt.time(x["at"].date)).font(.num(11, .regular)).foregroundStyle(t.mute)
                    }
                }
            } header: { Text("المستلمين") }
        }
        .listStyle(.insetGrouped)
        .overlay { if !r.loaded { RemoteBody(r: r) { EmptyView() } } }
        .oxScreen("تفاصيل الإرسال", page: "cast")
        .task { await r.load() }
        .refreshable { await r.load() }
    }
}

// MARK: - رسائل البوت
struct BotMessagesView: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var openKey: String? = nil
    let groups: [(String, [String])] = [
        ("الترحيب والحالة", ["welcome", "already", "statusIn", "statusOut", "leftNote", "stranger", "help"]),
        ("رسالة الفتح", ["openIntro", "openMessage", "openCta", "openFooter"]),
        ("الأزرار", ["joinLabel", "statusLabel", "leaveLabel", "helpLabel", "igLabel"]),
        ("ملف البوت", ["botHandle", "short", "description", "countText", "showCount"]),
    ]
    var body: some View {
        let n = store.v(P("notify"))
        Form {
            ForEach(groups.indices, id: \.self) { gi in
                let g = groups[gi]
                let keys = g.1.filter { !n[$0].isNull }
                if !keys.isEmpty {
                    Section(g.0) {
                        ForEach(keys, id: \.self) { k in
                            let v = n[k]
                            if v.isI18n || v.string != nil {
                                DisclosureGroup(isExpanded: Binding(get: { openKey == k }, set: { openKey = $0 ? k : nil })) {
                                    FieldRow(path: P("notify", k), label: "")
                                    TGBubble(html: v.isI18n ? v.ar : v.str).listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack { Text(Labels.label(k)).font(.ox(15)); if store.isDirty(P("notify", k)) { Circle().fill(prefs.theme.accent).frame(width: 7, height: 7) } }
                                        Text((v.isI18n ? v.ar : v.str).tgPlain).font(.ox(12)).foregroundStyle(prefs.theme.mute).lineLimit(1)
                                    }
                                }
                            } else { FieldRow(path: P("notify", k)) }
                        }
                    }
                }
            }
            let known = Set(groups.flatMap(\.1))
            let rest = n.keys.filter { !known.contains($0) }
            if !rest.isEmpty { Section("ثانية") { ForEach(rest, id: \.self) { k in FieldRow(path: P("notify", k)) } } }
        }
        .formStyle(.grouped)
        .oxScreen("رسائل البوت", page: "botmsgs")
    }
}
