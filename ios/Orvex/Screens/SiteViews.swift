import SwiftUI

// MARK: - فهرس الموقع
struct SiteView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let items: [(String, String, String, String, [String])] = [
            ("gate", "الاشتراكات", "door.left.hand.open", "الحالة والجدولة والعدّاد والأزرار", ["gate", "gate.state", "gate.schedule"]),
            ("mode", "وضع الموقع", "power", "يشتغل، صيانة، أو موقوف", ["mode.maintenance", "mode.offline"]),
            ("plans", "الباقات والأسعار", "tag.fill", "الأسعار والعروض وVIP", ["plans"]),
            ("content", "المحتوى والصفحات", "doc.richtext.fill", "كل قسم وكل صفحة", ["content"]),
            ("texts", "كل كلمة بالموقع", "textformat", "عدّل أو اخفِ أي كلمة", ["texts"]),
            ("mood", "مزاج الوقت", "sun.horizon.fill", "الألوان والترحيبات حسب الوقت", ["mood"]),
            ("train", "وضع التدريب", "figure.strengthtraining.traditional", "المدرّب الذكي داخل الموقع", ["train"]),
            ("look", "المظهر والأقسام", "paintpalette.fill", "إظهار وإخفاء الأقسام", ["look"]),
            ("geo", "حظر الدول وIP", "shield.lefthalf.filled", "احظر أي دولة أو عنوان", ["geo"]),
            ("advanced", "كل الإعدادات", "slider.horizontal.3", "كل إعداد بدون استثناء", ["advanced"]),
        ]
        List {
            Section {
                ForEach(items.indices, id: \.self) { i in
                    let it = items[i]
                    if session.canAny(it.4) {
                        NavigationLink(value: it.0) { RowLabel(title: it.1, icon: it.2, sub: it.3) }
                    }
                }
            }
            Section {
                Link(destination: URL(string: API.shared.base)!) { RowLabel(title: "افتح الموقع", icon: "safari.fill", sub: API.shared.base.replacingOccurrences(of: "https://", with: "")) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.load(force: true) }
        .oxScreen("الموقع", page: "site")
    }
}

// MARK: - الاشتراكات
struct GateView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    let states = ["open", "closed", "full", "soon", "custom"]
    let desc = ["open": "الزائر يكدر يشترك هسه", "closed": "مغلقة لوقت غير معلوم", "full": "العدد اكتمل وتفتح قريبًا", "soon": "تفتح قريبًا — تشويق", "custom": "نص تكتبه انت"]

    var body: some View {
        let t = prefs.theme
        let g = store.v(P("gate"))
        Form {
            Section { GatePreview().listRowInsets(EdgeInsets()).listRowBackground(Color.clear) } header: { Text("المعاينة") }
            if store.canPath(P("gate", "state")) {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(states, id: \.self) { st in
                            Button {
                                store.set(P("gate", "state"), .string(st))
                                let pre = store.meta["presets"][st]
                                if pre.isI18n, store.cfg["gate"]["state"].string != st { store.set(P("gate", "text"), pre) }
                                prefs.tap()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.meta["gateStates"][st].str).font(.ox(14, .semibold)).foregroundStyle(t.ink)
                                    Text(desc[st] ?? "").font(.ox(11.5)).foregroundStyle(t.mute).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                .background(g["state"].string == st ? t.accent.opacity(0.18) : t.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(g["state"].string == st ? t.accent : .clear, lineWidth: 1.5))
                            }.buttonStyle(.plain)
                        }
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                } header: { Text("الحالة") }
                Section { FieldRow(path: P("gate", "text")) }
            }
            if store.canPath(P("gate", "schedule")) { ScheduleSection() }
            if store.canPath(P("gate", "note")) {
                Section { FieldRow(path: P("gate", "note")); FieldRow(path: P("gate", "showUpdatedAt")) } header: { Text("تفاصيل") }
                Section {
                    NestedLink(path: P("gate", "countdown"))
                    NestedLink(path: P("gate", "seats"))
                    NestedLink(path: P("gate", "cta"))
                    NestedLink(path: P("gate", "remind"))
                } header: { Text("العدّاد والمقاعد والأزرار") }
            }
        }
        .formStyle(.grouped)
        .oxScreen("الاشتراكات", page: "gate")
        .task { await store.load() }
    }
}

struct ScheduleSection: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var sc: JSON { store.v(P("gate", "schedule")) }
    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { sc["enabled"].isTrue }, set: { on in
                var n = sc.isObject ? sc : ["enabled": false, "openAt": nil, "closeAt": nil, "closedState": "closed", "autoNotify": true]
                n["enabled"] = .bool(on)
                if on && n["openAt"].isNull { n["openAt"] = .number((Date().addingTimeInterval(86400).timeIntervalSince1970 * 1000).rounded()) }
                store.set(P("gate", "schedule"), n)
            })) { Label("فتح وإغلاق تلقائي", systemImage: "calendar.badge.clock").font(.ox(15)) }
            if sc["enabled"].isTrue {
                DateField(path: P("gate", "schedule", "openAt"), title: "موعد الفتح", dirty: store.isDirty(P("gate", "schedule", "openAt")))
                DateField(path: P("gate", "schedule", "closeAt"), title: "موعد الإغلاق (اختياري)", dirty: store.isDirty(P("gate", "schedule", "closeAt")))
                if sc["closedState"].string != nil { OptionField(path: P("gate", "schedule", "closedState"), title: "الحالة بعد الإغلاق", options: Labels.options(P("gate", "schedule", "closedState")) ?? []) }
                Toggle(isOn: Binding(get: { sc["autoNotify"].bool ?? true }, set: { store.set(P("gate", "schedule", "autoNotify"), .bool($0)) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("يرسل التذكير للمنتظرين تلقائيًا").font(.ox(15))
                        Text("أول ما تنفتح، على دفعات حتى يوصل للكل").font(.ox(12)).foregroundStyle(prefs.theme.mute)
                    }
                }
                Toggle(isOn: Binding(get: { sc["countdown"].bool ?? true }, set: { store.set(P("gate", "schedule", "countdown"), .bool($0)) })) {
                    Text("يعرض عدّاد تنازلي للفتح بالموقع").font(.ox(15))
                }
                if let o = sc["openAt"].date { timeline(o, sc["closeAt"].date) }
            }
        } header: { Text("الجدولة") } footer: { Text("الموقع يفتح ويسد بنفسه بالموعد حتى لو التطبيق مسدود. الإرسال التلقائي يحتاج تشغيل المهمة المجدولة (Cron) بإعدادات الـWorker.").font(.ox(12)) }
    }
    func timeline(_ open: Date, _ close: Date?) -> some View {
        let t = prefs.theme
        return VStack(alignment: .leading, spacing: 10) {
            step("calendar", "اليوم", "الحالة الحالية: " + (store.v(P("gate", "state")).str), t.mute)
            step("lock.open.fill", Fmt.date(open), "تنفتح الاشتراكات" + (sc["autoNotify"].bool ?? true ? " ويبدأ إرسال التذكير" : ""), t.ok)
            if let c = close { step("lock.fill", Fmt.date(c), "تنسد الاشتراكات", t.bad) }
        }.padding(.vertical, 6)
    }
    func step(_ icon: String, _ when: String, _ what: String, _ c: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(c).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(when).font(.ox(13, .semibold))
                Text(what).font(.ox(12)).foregroundStyle(prefs.theme.mute)
            }
        }
    }
}

/// معاينة تقريبية لصندوق الحالة بالموقع
struct GatePreview: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let g = store.v(P("gate")), t = AppTheme.iraqfit
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(g["state"].string == "open" ? t.ok : g["state"].string == "full" ? t.warn : t.mute).frame(width: 8, height: 8)
                    Text(store.meta["gateStates"][g["state"].str].str).font(.ox(13, .semibold)).foregroundStyle(t.ink)
                    Spacer()
                    Text("iraqfit.com").font(.num(10)).foregroundStyle(t.mute)
                }
                Text(g["text"].ar).font(.ox(15)).foregroundStyle(t.ink)
                if !g["note"].ar.isEmpty { Text(g["note"].ar).font(.ox(12.5)).foregroundStyle(t.mute) }
                if let at = countdownAt(g), at > ctx.date {
                    let s = Int(at.timeIntervalSince(ctx.date))
                    HStack(spacing: 6) {
                        let parts: [(Int, String)] = [(s / 86400, "يوم"), (s % 86400 / 3600, "ساعة"), (s % 3600 / 60, "دقيقة"), (s % 60, "ثانية")]
                        ForEach(parts.indices, id: \.self) { pi in let v = parts[pi]
                            VStack(spacing: 0) {
                                Text(String(format: "%02d", v.0)).font(.num(18, .bold)).foregroundStyle(t.ink)
                                Text(v.1).font(.ox(9.5)).foregroundStyle(t.mute)
                            }.frame(minWidth: 52).padding(.vertical, 6).background(t.surface2, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }.environment(\.layoutDirection, .rightToLeft)
                }
                if g["seats"]["enabled"].isTrue {
                    Text("🎟 متبقي \(Fmt.n(max(0, (g["seats"]["total"].double ?? 0) - (g["seats"]["taken"].double ?? 0)))) من \(Fmt.n(g["seats"]["total"]))").font(.ox(12.5)).foregroundStyle(t.ink2)
                }
                HStack {
                    if g["cta"]["enabled"].isTrue { Text(g["cta"]["label"].ar).font(.ox(13, .semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(t.accent, in: Capsule()).foregroundStyle(.white) }
                    if g["remind"]["enabled"].isTrue && g["state"].string != "open" { Label(g["remind"]["label"].ar, systemImage: "bell").font(.ox(12.5)).padding(.horizontal, 12).padding(.vertical, 8).background(t.surface2, in: Capsule()).foregroundStyle(t.ink) }
                }
            }
            .padding(16).background(t.bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(t.line))
        }
        .environment(\.colorScheme, .dark)
    }
    func countdownAt(_ g: JSON) -> Date? {
        if g["schedule"]["enabled"].isTrue, let o = g["schedule"]["openAt"].date, o > Date(), g["schedule"]["countdown"].bool != false { return o }
        if g["countdown"]["enabled"].isTrue { return g["countdown"]["at"].date }
        return nil
    }
}

// MARK: - وضع الموقع
struct ModeView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        let mode = store.v(P("mode")).str
        let modes: [(String, String, String, String, Color, String)] = [
            ("live", "يشتغل عادي", "الموقع مفتوح لكل الزوار", "checkmark.circle.fill", t.ok, ""),
            ("maintenance", "وضع الصيانة", "صفحة «نشتغل على تحسينات» مع عدّاد اختياري", "wrench.and.screwdriver.fill", t.warn, "mode.maintenance"),
            ("offline", "موقوف مؤقتًا", "صفحة خطأ بسيطة — استخدمه بحذر", "pause.circle.fill", t.bad, "mode.offline"),
        ]
        Form {
            Section {
                ForEach(modes.indices, id: \.self) { i in
                    let m = modes[i]
                    if m.5.isEmpty || session.can(m.5) {
                        Button {
                            store.set(P("mode"), .string(m.0)); prefs.tap()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: m.3).font(.system(size: 22)).foregroundStyle(m.4).frame(width: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.1).font(.ox(16, .semibold)).foregroundStyle(t.ink)
                                    Text(m.2).font(.ox(12.5)).foregroundStyle(t.mute)
                                }
                                Spacer()
                                Image(systemName: mode == m.0 ? "largecircle.fill.circle" : "circle").foregroundStyle(mode == m.0 ? m.4 : t.mute)
                            }.padding(.vertical, 6)
                        }.buttonStyle(.plain).accessibilityIdentifier("mode-\(m.0)")
                    }
                }
            } footer: {
                if mode != store.cfg["mode"].str { Label("يتغير لما تضغط «احفظ» — إجراء حساس", systemImage: "exclamationmark.triangle").font(.ox(12.5)).foregroundStyle(t.warn) }
            }
            if session.can("mode.maintenance") {
                Section { NestedLink(path: P("maintenance")) } header: { Text("صفحة الصيانة") }
            }
            if session.can("mode.offline") {
                Section { NestedLink(path: P("offline")) } header: { Text("صفحة الإيقاف") }
            }
        }
        .formStyle(.grouped)
        .oxScreen("وضع الموقع", page: "mode")
    }
}

// MARK: - الباقات
struct PlansView: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        Form {
            Section {
                ForEach(Array(store.v(P("plans")).arr.enumerated()), id: \.offset) { i, p in
                    NavigationLink(value: EditRoute(path: P("plans", i), title: p["title"].ar)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(p["title"].ar).font(.ox(15, .semibold))
                                    if p["featured"].isTrue { Pill(text: "الأكثر طلبًا", tone: "accent") }
                                    if p["offer"]["enabled"].isTrue { Pill(text: "عرض", tone: "ok") }
                                }
                                Text("\(Fmt.n(p["priceIQD"])) د.ع · $\(Fmt.n(p["priceUSD"]))").font(.num(13)).foregroundStyle(prefs.theme.mute)
                            }
                            Spacer()
                            if p["enabled"].bool == false { Pill(text: "مخفية") }
                        }
                    }
                }
                NavigationLink(value: EditRoute(path: P("plans"), title: "ترتيب الباقات")) { Label("ترتيب وإضافة وحذف", systemImage: "arrow.up.arrow.down").font(.ox(14)) }
            } header: { Text("الباقات") }
            Section {
                NestedLink(path: P("currency"))
                NestedLink(path: P("vip"))
                NestedLink(path: P("bar"))
            }
        }
        .formStyle(.grouped)
        .oxScreen("الباقات والأسعار", page: "plans")
    }
}

// MARK: - المحتوى
struct ContentView2: View {
    @ObservedObject var store = ConfigStore.shared
    let sections: [([Seg], String, String)] = [
        (P("brand"), "الهوية", "person.text.rectangle"), (P("cta"), "أزرار الدعوة", "hand.point.up.left.fill"), (P("included"), "ما تشمله الباقات", "checklist"),
        (P("counters"), "العدادات", "number"), (P("goals"), "اختر هدفك", "target"), (P("steps"), "خطوات المتابعة", "list.number"), (P("compare"), "جدول المقارنة", "tablecells"),
        (P("faq"), "الأسئلة الشائعة", "questionmark.bubble.fill"), (P("gym"), "القاعة والخريطة", "mappin.and.ellipse"), (P("gallery"), "معرض قبل/بعد", "photo.on.rectangle"),
        (P("changelog"), "تحديثات المنصة", "sparkles"), (P("pages", "about"), "صفحة «من أنا»", "person.fill"), (P("pages", "terms"), "صفحة الشروط", "doc.text.fill"),
        (P("pages", "privacy"), "صفحة الخصوصية", "lock.doc.fill"), (P("links"), "الروابط", "link"), (P("seo"), "SEO", "magnifyingglass"), (P("legal"), "الحقوق", "c.circle"), (P("developer"), "كرت المطوّر", "signature"),
    ]
    var body: some View {
        List {
            ForEach(sections.indices, id: \.self) { i in
                let s = sections[i]
                if store.canPath(s.0) && !store.v(s.0).isNull {
                    NavigationLink(value: EditRoute(path: s.0, title: s.1)) {
                        HStack {
                            RowLabel(title: s.1, icon: s.2, sub: sub(s.0))
                            if store.isDirty(s.0) { Circle().fill(Prefs.shared.theme.accent).frame(width: 8, height: 8) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .oxScreen("المحتوى والصفحات", page: "content")
    }
    func sub(_ p: [Seg]) -> String? {
        let v = store.v(p)
        if v.isArray { return "\(Fmt.n(v.arr.count)) عنصر" }
        if let e = v["enabled"].bool { return e ? "ظاهر" : "مخفي" }
        return nil
    }
}

// MARK: - كل كلمة
struct TextsView: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var q = ""
    @State private var filter = "all"
    var body: some View {
        let ov = store.v(P("texts", "over")), hd = store.v(P("texts", "hide"))
        let keys = store.ui.keys.filter { k in
            let u = store.ui[k]
            if filter == "mod" && ov[k].isNull { return false }
            if filter == "hid" && !hd["ui." + k].isTrue { return false }
            if q.count < 2 { return true }
            let n = norm(q)
            return norm(u["ar"].str).contains(n) || norm(u["en"].str).contains(n) || norm(ov[k]["ar"].str).contains(n)
        }
        List {
            Section {
                Picker("", selection: $filter) {
                    Text("الكل").tag("all"); Text("المعدّلة").tag("mod"); Text("المخفية").tag("hid")
                }.pickerStyle(.segmented).listRowBackground(Color.clear)
            }
            Section {
                ForEach(keys.prefix(200), id: \.self) { k in UIWordRow(key: k) }
            } footer: { Text("\(Fmt.n(keys.count)) كلمة").font(.ox(12)) }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $q, prompt: "ابحث عن أي كلمة مثل ما تشوفها بالموقع")
        .oxScreen("كل كلمة بالموقع", page: "texts")
    }
    func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "[\\u064B-\\u065F\\u0670\\u0640]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[أإآ]", with: "ا", options: .regularExpression).replacingOccurrences(of: "ة", with: "ه").replacingOccurrences(of: "ى", with: "ي")
    }
}
struct UIWordRow: View {
    let key: String
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let u = store.ui[key], op: [Seg] = [.key("texts"), .key("over"), .key(key)], ov = store.v(op)
        let hidden = store.v(P("texts", "hide"))["ui." + key].isTrue
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(u["oar"].str).font(.ox(13, .semibold)).foregroundStyle(prefs.theme.mute).lineLimit(1)
                if !ov.isNull { Pill(text: "معدّلة", tone: "accent") }
                if hidden { Pill(text: "مخفية", tone: "warn") }
                Spacer()
                if !ov.isNull { Button { store.set(op, nil) } label: { Image(systemName: "arrow.uturn.backward") }.buttonStyle(.borderless).accessibilityLabel("رجّع الأصل") }
                Button {
                    let hp: [Seg] = [.key("texts"), .key("hide"), .key("ui." + key)]
                    store.set(hp, hidden ? nil : .bool(true))
                } label: { Image(systemName: hidden ? "eye.slash.fill" : "eye") }.buttonStyle(.borderless)
            }
            TextField("عربي", text: binding("ar", u), axis: .vertical).font(.ox(15))
            TextField("English", text: binding("en", u), axis: .vertical).font(.ox(14)).environment(\.layoutDirection, .leftToRight).foregroundStyle(prefs.theme.ink2)
        }
        .opacity(hidden ? 0.6 : 1)
        .padding(.vertical, 4)
    }
    func binding(_ l: String, _ u: JSON) -> Binding<String> {
        let op: [Seg] = [.key("texts"), .key("over"), .key(key)]
        return Binding(get: {
            let ov = store.v(op)
            return ov.isNull ? u["o" + l].str : ov[l].str
        }, set: { nv in
            var ov = store.v(op)
            if ov.isNull { ov = ["ar": .string(u["oar"].str), "en": .string(u["oen"].str)] }
            ov[l] = .string(nv)
            if ov["ar"].str == u["oar"].str && ov["en"].str == u["oen"].str { store.set(op, nil) } else { store.set(op, ov) }
        })
    }
}

// MARK: - مزاج الوقت
struct MoodView: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    let periods: [(String, String, String)] = [("morning", "الصبح", "sunrise.fill"), ("noon", "العصر", "sun.max.fill"), ("evening", "المغرب", "sunset.fill"), ("night", "الليل", "moon.stars.fill")]
    var body: some View {
        Form {
            Section {
                FieldRow(path: P("mood", "enabled"))
                FieldRow(path: P("mood", "palette"))
                FieldRow(path: P("mood", "greet"))
                FieldRow(path: P("mood", "mode"))
                Button { store.set(P("mood", "offset"), .number((store.v(P("mood", "offset")).double ?? 0) + 1)); Toasts.shared.show("تبدلت — اضغط «احفظ»") } label: { Label("بدّل ترحيبات اليوم", systemImage: "shuffle") }
            }
            ForEach(periods.indices, id: \.self) { i in
                let p = periods[i]
                Section {
                    FieldRow(path: P("mood", "starts", p.0), label: "تبدأ الساعة")
                    FieldRow(path: P("mood", "on", p.0), label: "ألوان هالفترة شغّالة")
                    FieldRow(path: P("mood", "theme", p.0), label: "أساس الألوان")
                    HStack { Text("اليوم").font(.ox(13)).foregroundStyle(prefs.theme.mute); Text(pick(p.0, 0)).font(.ox(14)) }
                    HStack { Text("باچر").font(.ox(13)).foregroundStyle(prefs.theme.mute); Text(pick(p.0, 1)).font(.ox(14)) }
                    NavigationLink(value: EditRoute(path: P("mood", "list", p.0), title: "ترحيبات " + p.1)) {
                        Text("الترحيبات (\(Fmt.n(store.v(P("mood", "list", p.0)).arr.count)))").font(.ox(15))
                    }
                } header: { Label(p.1, systemImage: p.2) }
            }
        }
        .formStyle(.grouped)
        .oxScreen("مزاج الوقت", page: "mood")
    }
    func pick(_ period: String, _ add: Int) -> String {
        let md = store.v(P("mood"))
        let list = md["list"][period].arr.filter { $0["on"].bool != false && !$0["ar"].str.isEmpty }
        guard !list.isEmpty else { return "—" }
        if md["mode"].string == "random" { return "عشوائي" }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = Fmt.baghdad
        let day = Int(cal.startOfDay(for: Date().addingTimeInterval(Double(add) * 86400)).timeIntervalSince1970 + 10800) / 86400 + (md["offset"].int ?? 0)
        return list[((day % list.count) + list.count) % list.count]["ar"].str
    }
}

// MARK: - المظهر والأقسام
struct LookView: View {
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        Form {
            Section { ConfigFields(path: P("ui")) } header: { Text("المظهر الافتراضي للزوار") }
            Section { ConfigFields(path: P("visitors")) } header: { Text("عدّاد المتصفحين بالموقع") }
            Section {
                ForEach(store.meta["sections"].arr.indices, id: \.self) { i in
                    let s = store.meta["sections"].arr[i]
                    let p = s["p"].str.split(separator: ".").map { Seg.key(String($0)) }
                    if store.v(p).bool != nil && store.canPath(p) {
                        Toggle(isOn: store.bool(p)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s["p"].str == "developer.enabled" ? "كرت المطوّر (أورفيكس)" : s["n"].str).font(.ox(15))
                                if !s["d"].str.isEmpty { Text(s["d"].str).font(.ox(12)).foregroundStyle(.secondary).lineLimit(2) }
                            }
                        }
                    }
                }
            } header: { Text("أقسام الموقع") }
        }
        .formStyle(.grouped)
        .oxScreen("المظهر والأقسام", page: "look")
    }
}

// MARK: - كل الإعدادات
struct AdvancedView: View {
    @ObservedObject var store = ConfigStore.shared
    @State private var json: (key: String, text: String)? = nil
    let skip: Set<String> = ["audit", "rev", "updatedAt", "updatedBy", "v", "stats", "modeBefore"]
    var body: some View {
        List {
            ForEach(store.draft.keys.filter { !skip.contains($0) && store.canPath([.key($0)]) }, id: \.self) { k in
                let v = store.v([.key(k)])
                if v.isObject && !v.isI18n || v.isArray {
                    NavigationLink(value: EditRoute(path: [.key(k)], title: Labels.label(k))) { RowLabel(title: Labels.label(k), icon: "folder.fill", sub: k) }
                        .contextMenu { Button("عرض JSON") { json = (k, JSONCodec.string(v, pretty: true)) } }
                } else {
                    FieldRow(path: [.key(k)])
                }
            }
        }
        .listStyle(.insetGrouped)
        .oxScreen("كل الإعدادات", page: "advanced")
        .sheet(isPresented: Binding(get: { json != nil }, set: { if !$0 { json = nil } })) {
            if let j = json { JSONEditorSheet(key: j.key, initial: j.text) }
        }
    }
}
struct JSONEditorSheet: View {
    let key: String
    let initial: String
    @State private var text = ""
    @State private var err: String?
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text).font(.system(size: 12, design: .monospaced)).environment(\.layoutDirection, .leftToRight)
                if let e = err { Text(e).font(.ox(12)).foregroundStyle(.red) }
            }.padding()
            .navigationTitle(Labels.label(key)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("طبّق") {
                        do { let v = try JSONCodec.parse(text); store.set([.key(key)], v); store.structural([.key(key)]); dismiss() }
                        catch { err = "صيغة JSON غلط" }
                    }
                }
            }
        }.onAppear { text = initial }
    }
}
