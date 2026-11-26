import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    @State private var overview: JSON = .null
    @State private var timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var s: JSON { session.status }

    var body: some View {
        let t = prefs.theme
        ScrollView {
            VStack(spacing: 14) {
                header
                if let a = session.alert, !a["title"].str.isEmpty { alertBanner(a) }
                if let up = session.pendingUpdate { updateBanner(up) }
                ForEach(prefs.d.homeCards.filter { !prefs.d.hiddenHomeCards.contains($0) }, id: \.self) { c in card(c) }
                Text("أورفيكس \(Bundle.main.version) · \(session.lastSync.map { "آخر مزامنة " + Fmt.time($0) } ?? "")")
                    .font(.ox(11)).foregroundStyle(t.mute).padding(.top, 6)
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
            .frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .refreshable { await load() }
        .oxScreen("أهلًا \(session.name.split(separator: " ").first.map(String.init) ?? "")", page: "home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: "search") { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("البحث").accessibilityIdentifier("searchBtn")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: "inbox") {
                    Image(systemName: session.unread > 0 ? "bell.badge.fill" : "bell")
                        .symbolRenderingMode(.palette).foregroundStyle(t.bad, t.ink)
                }.accessibilityLabel("الإشعارات")
            }
        }
        .task { await load() }
        .onReceive(timer) { _ in Task { await load(silent: true) } }
    }

    func load(silent: Bool = false) async {
        async let st: Void = session.refreshStatus()
        async let ov = try? API.shared.get("/overview")
        _ = await st
        if let o = await ov { withAnimation { overview = o } }
    }

    // MARK: الترويسة: حالة الموقع
    var header: some View {
        let t = prefs.theme
        let h = s["health"].string ?? "ok"
        let (title, tone, icon): (String, String, String) = {
            switch h {
            case "maintenance": return ("الموقع بوضع الصيانة", "warn", "wrench.and.screwdriver.fill")
            case "down": return ("الموقع متوقف", "bad", "pause.circle.fill")
            case "warn": return ("توجد مشكلة", "bad", "exclamationmark.triangle.fill")
            default: return ("الموقع يعمل", "ok", "checkmark.seal.fill")
            }
        }()
        let c = toneColor(tone, t) ?? t.ok
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(c.opacity(0.16)).frame(width: 58, height: 58)
                Image(systemName: icon).font(.system(size: 24, weight: .semibold)).foregroundStyle(c)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.ox(20, .bold)).foregroundStyle(t.ink)
                if let p = s["problems"].arr.first { Text(p["t"].str).font(.ox(13)).foregroundStyle(t.bad).lineLimit(2) }
                else { Text("الاشتراكات: \(s["gate"]["label"].text.isEmpty ? "—" : s["gate"]["label"].text)").font(.ox(13)).foregroundStyle(t.mute) }
            }
            Spacer(minLength: 0)
            if s["live"].int != nil && session.canAny(["stats", "live"]) {
                VStack(spacing: 2) {
                    HStack(spacing: 5) { PulseDot(color: t.ok); Text(Fmt.n(s["live"].int)).font(.num(22, .bold)).foregroundStyle(t.ink).contentTransition(.numericText()) }
                    Text("هسه").font(.ox(11)).foregroundStyle(t.mute)
                }
            }
        }
        .padding(16)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(c.opacity(0.35)))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder func card(_ id: String) -> some View {
        switch id {
        case "kpis": if session.canAny(["stats", "live", "waitlist.view"]) { kpis }
        case "gate": if session.canAny(["gate.state", "gate.schedule"]) { gateCard }
        case "actions": actions
        case "live": if session.can("stats") { liveCard }
        case "recent": if session.can("history.view") { recentCard }
        default: EmptyView()
        }
    }

    var kpis: some View {
        let today = s["today"]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if session.canAny(["stats", "live"]) {
                KPI(title: "زيارات اليوم", value: Fmt.n(today["views"]), icon: "chart.bar.fill", foot: delta(today["views"].double, overview["stats"]["yesterday"]["views"].double))
                KPI(title: "زوار اليوم", value: Fmt.n(today["uniq"]), icon: "person.2.fill", foot: "جدد \(Fmt.n(today["new"]))")
                KPI(title: "ضغطات الاشتراك", value: Fmt.n(today["cta"]), icon: "hand.tap.fill", foot: "ذكّرني \(Fmt.n(today["rem"]))")
            }
            if session.can("waitlist.view") {
                KPI(title: "المنتظرون", value: Fmt.n(s["waitlist"]), icon: "bell.fill", foot: s["cast"].isObject ? "إرسال شغّال…" : "بقائمة التذكير", tone: s["cast"].isObject ? "info" : nil)
            }
        }
    }
    func delta(_ a: Double?, _ b: Double?) -> String {
        guard let a, let b, b > 0 else { return "اليوم" }
        let d = Int(((a - b) / b * 100).rounded())
        return (d >= 0 ? "▲ " : "▼ ") + "\(abs(d))% عن أمس"
    }

    var gateCard: some View {
        let t = prefs.theme
        let state = s["gate"]["state"].string ?? store.cfg["gate"]["state"].str
        let states = ["open", "closed", "full", "soon"]
        return Card(title: "الاشتراكات", icon: "door.left.hand.open", trailing: AnyView(NavigationLink(value: "gate") { Text("الكل").font(.ox(13)) })) {
            HStack(spacing: 8) {
                Pill(text: s["gate"]["label"].text, tone: Labels.gateTone[state] ?? "mute")
                if let n = s["schedule"]["next"].object, let at = n["at"]?.date {
                    Pill(text: (n["kind"]?.string == "open" ? "يفتح " : "ينسد ") + Fmt.ago(at).replacingOccurrences(of: "قبل", with: "بعد"), tone: "info", icon: "calendar")
                }
            }
            Text(s["gate"]["text"].str).font(.ox(13.5)).foregroundStyle(t.ink2).lineLimit(3)
            if session.can("gate.state") {
                HStack(spacing: 8) {
                    ForEach(states, id: \.self) { st in
                        Button {
                            Task { await setState(st) }
                        } label: {
                            Text(gateName(st)).font(.ox(13, st == state ? .semibold : .regular)).frame(maxWidth: .infinity).padding(.vertical, 9)
                                .foregroundStyle(st == state ? t.onAccent : t.ink2)
                                .background(st == state ? t.accent : t.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }.buttonStyle(.plain).accessibilityIdentifier("gate-\(st)")
                    }
                }
            }
        }
    }
    func gateName(_ s: String) -> String { ["open": "مفتوحة", "closed": "مغلقة", "full": "اكتملت", "soon": "قريبًا"][s] ?? s }
    func setState(_ st: String) async {
        await store.load()
        let pre = store.meta["presets"][st]
        var ch: [([Seg], JSON?)] = [(P("gate", "state"), .string(st))]
        if pre.isI18n { ch.append((P("gate", "text"), pre)) }
        await store.quick(ch, what: "حالة الاشتراكات ← \(gateName(st))")
    }

    var actions: some View {
        let items: [(String, String, String, Bool)] = [
            ("gate", "الاشتراكات", "door.left.hand.open", session.canAny(["gate", "gate.state", "gate.schedule"])),
            ("cast", "أرسل تذكير", "paperplane.fill", session.can("waitlist.cast")),
            ("mode", "وضع الموقع", "power", session.canAny(["mode.maintenance", "mode.offline"])),
            ("files", "رفع ملف", "arrow.up.doc.fill", session.can("files.upload")),
            ("notify-send", "إشعار", "bell.badge.fill", session.can("app.notify")),
            ("geo", "الحظر", "shield.lefthalf.filled", session.can("geo")),
            ("monitor", "المراقبة", "eye.fill", session.can("monitor")),
            ("history", "السجل", "clock.arrow.circlepath", session.can("history.view")),
        ].filter { $0.3 }
        return Card(title: "إجراءات سريعة", icon: "bolt.fill") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(items.indices, id: \.self) { idx in let it = items[idx]
                    NavigationLink(value: it.0) {
                        VStack(spacing: 7) {
                            Image(systemName: it.2).font(.system(size: 19, weight: .semibold)).foregroundStyle(prefs.theme.ink)
                                .frame(width: 50, height: 50).glassRect(16, interactive: true)
                            Text(it.1).font(.ox(11.5)).foregroundStyle(prefs.theme.ink2).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    var liveCard: some View {
        let list = overview["stats"]["liveList"].arr
        return Card(title: "المتصفحين هسه", icon: "dot.radiowaves.left.and.right", trailing: AnyView(NavigationLink(value: "live") { Text("الكل").font(.ox(13)) })) {
            if list.isEmpty { EmptyState(icon: "moon.zzz", text: "ماكو أحد يتصفح هسه") }
            ForEach(Array(list.prefix(5).enumerated()), id: \.offset) { _, v in LiveRow(v: v) }
        }
    }
    var recentCard: some View {
        let list = overview["recent"].arr
        return Card(title: "آخر التعديلات", icon: "clock.arrow.circlepath", trailing: AnyView(NavigationLink(value: "history") { Text("السجل").font(.ox(13)) })) {
            if list.isEmpty { EmptyState(icon: "tray", text: "ماكو تعديلات بعد") }
            ForEach(Array(list.prefix(5).enumerated()), id: \.offset) { _, v in
                HStack(spacing: 10) {
                    Image(systemName: v["via"].string == "bot" ? "paperplane" : v["kind"].string == "undo" ? "arrow.uturn.backward" : "checkmark")
                        .font(.system(size: 13, weight: .semibold)).frame(width: 30, height: 30)
                        .background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v["what"].str).font(.ox(14)).lineLimit(2).foregroundStyle(prefs.theme.ink)
                        Text("\(v["uname"].str) · \(Fmt.ago(v["at"].date))").font(.ox(11.5)).foregroundStyle(prefs.theme.mute)
                    }
                    Spacer(minLength: 0)
                    if session.can("history.undo") && v["kind"].string != "base" {
                        AsyncButton(action: { await store.undo(v["id"].int ?? 0); await load() }) { Image(systemName: "arrow.uturn.backward.circle") }.buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    func alertBanner(_ a: JSON) -> some View {
        let tone = a["level"].string == "bad" ? "bad" : "warn"
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(toneColor(tone, prefs.theme) ?? .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(a["title"].str).font(.ox(15, .semibold))
                if !a["body"].str.isEmpty { Text(a["body"].str).font(.ox(13)).foregroundStyle(prefs.theme.ink2) }
            }
            Spacer()
            Button { session.alert = nil } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }.buttonStyle(.borderless)
        }
        .padding(14).glassRect(20, tint: toneColor(tone, prefs.theme))
    }
    func updateBanner(_ up: JSON) -> some View {
        Button { session.pendingUpdate = up } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("تحديث جديد \(up["version"].str)").font(.ox(15, .semibold))
                    Text(up["notes"].arr.first?.str ?? "اضغط للتفاصيل").font(.ox(12.5)).foregroundStyle(prefs.theme.ink2).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
            }.foregroundStyle(prefs.theme.ink).padding(14).glassRect(20, tint: prefs.theme.info, interactive: true)
        }.buttonStyle(.plain)
    }
}

struct LiveRow: View {
    let v: JSON
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        HStack(spacing: 12) {
            Text(flag(v["cc"].str)).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(v["city"].str.isEmpty ? countryName(v["cc"].str) : cityName(v["city"].str) + " · " + countryName(v["cc"].str)).font(.ox(14, .medium)).foregroundStyle(prefs.theme.ink)
                Text([Labels.os[v["os"].str], Labels.browsers[v["br"].str], Labels.sources[v["src"].str]].compactMap { $0 }.joined(separator: " · ")).font(.ox(12)).foregroundStyle(prefs.theme.mute).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: v["dev"].string == "desk" ? "desktopcomputer" : v["dev"].string == "tab" ? "ipad" : "iphone").foregroundStyle(prefs.theme.mute)
            if let since = v["since"].double, let last = v["last"].double { Text(Fmt.dur((last - since) / 1000 + 30)).font(.num(11)).foregroundStyle(prefs.theme.mute) }
        }.accessibilityElement(children: .combine)
    }
}
