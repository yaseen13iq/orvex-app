import SwiftUI

// MARK: - تبويب «الموقع»
struct SiteView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let gate = store.v(P("gate")), mode = store.v(P("mode")).str
        let sched = gate["schedule"]
        Page(title: "الموقع", intro: "كل ما يظهر للزائر في iraqfit.com، مقسّمًا حسب الموضوع.", id: "site") {
            if !store.loaded { LoadingView() } else {
                if session.canAny(["gate", "gate.state", "gate.schedule", "plans"]) {
                    SectionTitle("الاشتراكات والأسعار")
                    Card {
                        if session.canAny(["gate", "gate.state"]) {
                            NavRow(value: "gate", title: "حالة الاشتراكات", sub: "مفتوحة، أو مغلقة، أو تُفتح قريبًا", icon: "door.left.hand.open", color: "green",
                                   pill: (Defs.gateStates.first { $0.0 == gate["state"].str }?.1 ?? "—", gate["state"].str == "open" ? "ok" : gate["state"].str == "soon" ? "warn" : "mute"))
                        }
                        if session.can("gate.schedule") {
                            NavRow(value: "schedule", title: "جدولة الفتح والإغلاق", sub: "فتح الاشتراكات تلقائيًا في موعد محدّد", icon: "calendar.badge.clock", color: "blue",
                                   trailing: sched["enabled"].isTrue ? Fmt.shortDate(sched["openAt"].date) : "غير مفعّلة")
                        }
                        if session.can("plans") {
                            NavRow(value: "plans", title: "الباقات والأسعار", sub: planSummary, icon: "tag.fill", color: "amber")
                            NavRow(value: AnyHashableRoute.form("vip", P("vip")), title: "باقة VIP", sub: "التدريب الشخصي داخل القاعة", icon: "crown.fill", color: "orange")
                            NavRow(value: "pricing", title: "العملة وشريط الاشتراك", sub: "الدينار والدولار والشريط السفلي", icon: "dollarsign.circle.fill", color: "teal")
                        }
                    }
                }
                if session.canAny(["content", "look", "texts"]) {
                    SectionTitle("المحتوى")
                    Card {
                        if session.canAny(["content", "look"]) {
                            NavRow(value: "sections", title: "أقسام الصفحة الرئيسية", sub: "تعديل كل قسم أو إخفاؤه", icon: "square.stack.3d.up.fill", color: "indigo")
                        }
                        if session.can("content") {
                            NavRow(value: "faq", title: "الأسئلة الشائعة", sub: "\(Fmt.n(store.v(P("faq")).arr.count)) سؤالًا", icon: "questionmark.bubble.fill", color: "teal")
                            NavRow(value: "pages", title: "الصفحات الإضافية", sub: "من أنا، والشروط، والخصوصية", icon: "doc.text.fill", color: "graphite")
                            NavRow(value: "links", title: "الروابط والتواصل", sub: "إنستغرام وواتساب والبريد", icon: "link", color: "steel")
                        }
                        if session.can("texts") {
                            NavRow(value: "texts", title: "البحث في نصوص الموقع", sub: "تعديل أي عبارة أو إخفاؤها", icon: "character.cursor.ibeam", color: "purple")
                        }
                    }
                }
                if session.canAny(["look", "mood", "content"]) {
                    SectionTitle("المظهر")
                    Card {
                        if session.can("look") { NavRow(value: "look", title: "المظهر الافتراضي للزوار", sub: "الوضع الداكن أو الفاتح واللون", icon: "paintpalette.fill", color: "pink") }
                        if session.can("mood") { NavRow(value: "mood", title: "الترحيب حسب الوقت", sub: "عبارة وألوان تتغيّر بين الصباح والليل", icon: "sun.horizon.fill", color: "amber") }
                        if session.can("content") { NavRow(value: "seo", title: "محركات البحث والحقوق", sub: "العنوان في Google وحقوق النشر", icon: "magnifyingglass", color: "graphite") }
                    }
                }
                if session.canAny(["mode.maintenance", "mode.offline", "geo"]) {
                    SectionTitle("التشغيل والحماية")
                    Card {
                        if session.canAny(["mode.maintenance", "mode.offline"]) {
                            NavRow(value: "mode", title: "وضع الموقع", sub: "تشغيل، أو صيانة، أو إيقاف", icon: "power", color: mode == "live" ? "green" : mode == "maintenance" ? "amber" : "red",
                                   pill: mode == "live" ? ("يعمل", "ok") : mode == "maintenance" ? ("صيانة", "warn") : ("متوقف", "bad"))
                        }
                        if session.can("geo") {
                            let g = store.v(P("geo"))
                            NavRow(value: "geo", title: "حظر الدول والعناوين", sub: "منع الوصول من دول أو عناوين IP محدّدة", icon: "shield.lefthalf.filled", color: "red",
                                   trailing: g["enabled"].isTrue ? "\(Fmt.n(g["countries"].arr.count + g["ips"].arr.count)) قاعدة" : "غير مفعّل")
                        }
                    }
                }
                Spacer().frame(height: 18)
                Link(destination: URL(string: API.shared.base) ?? URL(string: "https://iraqfit.com")!) {
                    Label("فتح الموقع في Safari", systemImage: "safari").font(.ox(14.5, .medium)).foregroundStyle(C.info).frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: "search") { Image(systemName: "magnifyingglass") }.accessibilityLabel("البحث").accessibilityIdentifier("searchBtn") } }
        .refreshable { await store.load(force: true) }
        .task { await store.load() }
    }
    var planSummary: String {
        let plans = store.v(P("plans")).arr.filter { $0["enabled"].bool != false }
        return plans.count == 1 ? "باقة واحدة ظاهرة" : "\(Fmt.n(plans.count)) باقات ظاهرة"
    }
}

// MARK: - حالة الاشتراكات
struct GateView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @State private var lang = "ar"
    let desc = ["open": "يمكن الاشتراك الآن", "soon": "للتشويق قبل الفتح", "full": "اكتمل العدد المطلوب", "closed": "مغلقة لوقت غير محدّد", "custom": "نص تكتبه بنفسك"]
    let dots: [String: UInt32] = ["open": 0x1F9D57, "soon": 0xE2A33C, "full": 0xD33A3A, "closed": 0x7A818C, "custom": 0x8A4FC7]
    var body: some View {
        let g = store.v(P("gate"))
        Page(title: "حالة الاشتراكات", intro: "اختر ما يراه الزائر في صندوق الاشتراك. لن يتغيّر شيء في الموقع قبل الضغط على «حفظ».", id: "gate") {
            if !store.loaded { LoadingView() } else {
                if store.canPath(P("gate", "state")) {
                    SectionTitle("الحالة")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Defs.gateStates.indices, id: \.self) { i in
                            let st = Defs.gateStates[i], on = g["state"].str == st.0
                            Button { choose(st.0) } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(Color(hex: dots[st.0] ?? 0x7A818C)).frame(width: 10, height: 10).padding(.top, 5)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(st.1).font(.ox(15, .semibold)).foregroundStyle(C.ink)
                                        Text(desc[st.0] ?? "").font(.ox(11.5)).foregroundStyle(C.mute).lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(13).frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                                .background(C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? C.ink : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain).accessibilityIdentifier("state-" + st.0)
                        }
                    }
                    .padding(.horizontal, 16)
                    SectionTitle("النص الظاهر للزائر")
                    LangSwitch(lang: $lang).padding(.bottom, 10)
                    Card { FieldView(path: P("gate", "text"), field: Field("text", lang == "ar" ? "بالعربية" : "بالإنجليزية", .long)).environment(\.editLang, lang) }
                    SectionFooter("عند اختيار حالة جديدة يُقترح نصها تلقائيًا، ويمكنك تعديله.")
                }
                SectionTitle("المعاينة كما تظهر في الموقع")
                GatePreview()
                if store.canPath(P("gate", "cta")) || store.canPath(P("gate", "schedule")) {
                    SectionTitle("المزيد")
                    Card {
                        if store.canPath(P("gate", "cta")) {
                            NavRow(value: AnyHashableRoute.form("gate-extra", P("gate")), title: "أزرار صندوق الاشتراك", sub: "زر الاشتراك، وزر التذكير، والمقاعد، والعدّاد", icon: "rectangle.and.hand.point.up.left.fill", color: "indigo")
                        }
                        if session.can("gate.schedule") {
                            NavRow(value: "schedule", title: "جدولة الفتح والإغلاق", sub: "فتح الاشتراكات تلقائيًا في موعد محدّد", icon: "calendar.badge.clock", color: "blue")
                        }
                    }
                }
            }
        }
    }
    func choose(_ st: String) {
        Haptics.tap()
        guard store.v(P("gate", "state")).str != st else { return }
        store.set(P("gate", "state"), .string(st))
        let pre = store.meta["presets"][st]
        if pre.isI18n { store.set(P("gate", "text"), pre) }
    }
}

/// معاينة صندوق الاشتراك بشكل الموقع
struct GatePreview: View {
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let g = store.v(P("gate"))
        let state = Defs.gateStates.first { $0.0 == g["state"].str }?.1 ?? ""
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(g["state"].str == "open" ? Color(hex: 0x3DD68C) : g["state"].str == "full" ? Color(hex: 0xF0626A) : Color(hex: 0xF0B44C)).frame(width: 8, height: 8)
                    Text(state).font(.ox(12.5, .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text("iraqfit.com").font(.num(10, .medium)).foregroundStyle(Color(hex: 0x8A919C))
                }
                Text(g["text"].ar).font(.ox(15)).foregroundStyle(.white).lineSpacing(3)
                if !g["note"].ar.isEmpty { Text(g["note"].ar).font(.ox(12.5)).foregroundStyle(Color(hex: 0x9AA1AB)) }
                if let at = countdownAt(g), at > ctx.date {
                    let s = Int(at.timeIntervalSince(ctx.date))
                    let parts: [(Int, String)] = [(s / 86400, "يوم"), (s % 86400 / 3600, "ساعة"), (s % 3600 / 60, "دقيقة"), (s % 60, "ثانية")]
                    HStack(spacing: 6) {
                        ForEach(parts.indices, id: \.self) { i in
                            VStack(spacing: 1) {
                                Text(String(format: "%02d", parts[i].0)).font(.num(17)).foregroundStyle(.white)
                                Text(parts[i].1).font(.ox(9.5)).foregroundStyle(Color(hex: 0x8A919C))
                            }.frame(maxWidth: .infinity).padding(.vertical, 7).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if g["seats"]["enabled"].isTrue {
                    let left = max(0, (g["seats"]["total"].double ?? 0) - (g["seats"]["taken"].double ?? 0))
                    Text("المقاعد المتبقية: \(Fmt.n(left)) من \(Fmt.n(g["seats"]["total"]))").font(.ox(12.5)).foregroundStyle(Color(hex: 0xC9CDD3))
                }
                HStack(spacing: 8) {
                    if g["cta"]["enabled"].isTrue && !g["cta"]["label"].ar.isEmpty {
                        Text(g["cta"]["label"].ar).font(.ox(13, .semibold)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 8).background(Color(hex: 0xE2733C), in: Capsule())
                    }
                    if g["remind"]["enabled"].isTrue && g["state"].str != "open" {
                        Label(g["remind"]["label"].ar, systemImage: "bell").font(.ox(12.5)).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8).background(.white.opacity(0.1), in: Capsule())
                    }
                }
            }
            .padding(16)
            .background(Color(hex: 0x121418), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
        }
    }
    func countdownAt(_ g: JSON) -> Date? {
        if g["schedule"]["enabled"].isTrue, let o = g["schedule"]["openAt"].date, o > Date(), g["schedule"]["countdown"].bool != false { return o }
        if g["countdown"]["enabled"].isTrue { return g["countdown"]["at"].date }
        return nil
    }
}

// MARK: - الجدولة
struct ScheduleView: View {
    @ObservedObject var store = ConfigStore.shared
    var sc: JSON { store.v(P("gate", "schedule")) }
    var body: some View {
        Page(title: "جدولة الفتح والإغلاق", intro: "حدّد موعدًا تُفتح فيه الاشتراكات تلقائيًا، ويُرسَل التذكير للمنتظرين، حتى لو كان التطبيق مغلقًا.", id: "schedule") {
            if !store.loaded { LoadingView() } else {
                Spacer().frame(height: 10)
                Card {
                    ToggleRow(title: "تفعيل الجدولة", sub: sc["enabled"].isTrue ? "الاشتراكات ستُفتح في الموعد المحدّد أدناه" : "الاشتراكات تُدار يدويًا حاليًا", isOn: Binding(get: { sc["enabled"].isTrue }, set: { on in
                        var n = sc.isObject ? sc : ["enabled": false, "openAt": nil, "closeAt": nil, "closedState": "closed", "autoNotify": true, "countdown": true]
                        n["enabled"] = .bool(on)
                        if on && n["openAt"].isNull { n["openAt"] = .number(((Date().addingTimeInterval(86400).timeIntervalSince1970 / 3600).rounded(.up) * 3600 * 1000)) }
                        store.set(P("gate", "schedule"), n)
                    }))
                }
                if sc["enabled"].isTrue {
                    SectionTitle("المواعيد (بتوقيت بغداد)")
                    Card {
                        DateFieldRow(title: "موعد الفتح", path: P("gate", "schedule", "openAt"))
                        DateFieldRow(title: "موعد الإغلاق", help: "اختياري. اتركه معطّلًا إذا لم تُرد إغلاقها تلقائيًا.", path: P("gate", "schedule", "closeAt"))
                        if !sc["closeAt"].isNull {
                            ChoiceRow(title: "الحالة بعد الإغلاق", options: [("closed", "مغلقة"), ("full", "اكتمل العدد"), ("soon", "تُفتح قريبًا")],
                                      selection: Binding(get: { sc["closedState"].string ?? "closed" }, set: { store.set(P("gate", "schedule", "closedState"), .string($0)) }))
                        }
                    }
                    SectionTitle("عند الفتح")
                    Card {
                        ToggleRow(title: "إرسال التذكير للمنتظرين تلقائيًا", sub: "يُرسل على دفعات حتى يصل إلى الجميع", isOn: Binding(get: { sc["autoNotify"].bool ?? true }, set: { store.set(P("gate", "schedule", "autoNotify"), .bool($0)) }))
                        ToggleRow(title: "إظهار عدّاد تنازلي في الموقع", sub: "يعدّ الوقت المتبقي حتى الفتح", isOn: Binding(get: { sc["countdown"].bool ?? true }, set: { store.set(P("gate", "schedule", "countdown"), .bool($0)) }))
                    }
                    if let o = sc["openAt"].date {
                        SectionTitle("ما سيحدث")
                        Card(padded: true) {
                            VStack(alignment: .leading, spacing: 14) {
                                step("calendar", "الآن", "الحالة الحالية: " + (Defs.gateStates.first { $0.0 == store.v(P("gate", "state")).str }?.1 ?? "—"), C.mute)
                                step("lock.open.fill", Fmt.date(o), "تُفتح الاشتراكات" + ((sc["autoNotify"].bool ?? true) ? " ويبدأ إرسال التذكير" : ""), C.ok)
                                if let c = sc["closeAt"].date { step("lock.fill", Fmt.date(c), "تُغلق الاشتراكات", C.bad) }
                            }
                        }
                    }
                    Spacer().frame(height: 12)
                    Note(text: "يعمل الفتح التلقائي عبر المهمة المجدولة (Cron) في إعدادات الـWorker. تأكّد من تفعيلها من «حالة النظام».", tone: "info")
                }
            }
        }
    }
    func step(_ icon: String, _ when: String, _ what: String, _ c: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(c).frame(width: 24).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(when).font(.ox(14, .semibold)).foregroundStyle(C.ink)
                Text(what).font(.ox(13)).foregroundStyle(C.mute)
            }
        }
    }
}

// MARK: - أقسام الصفحة الرئيسية
struct HomeSectionsView: View {
    @ObservedObject var store = ConfigStore.shared
    struct Sec { let title: String; let icon: String; let color: String; let toggle: [Seg]?; let route: AnyHashableRoute }
    let secs: [Sec] = [
        Sec(title: "التعريف والأزرار", icon: "person.text.rectangle", color: "graphite", toggle: nil, route: .form("intro", [])),
        Sec(title: "الأرقام", icon: "number", color: "blue", toggle: nil, route: .list("counters", P("counters"))),
        Sec(title: "ما تشمله الباقات", icon: "checklist", color: "green", toggle: P("included", "enabled"), route: .form("included", P("included"))),
        Sec(title: "اختر هدفك", icon: "target", color: "red", toggle: P("goals", "enabled"), route: .form("goals", P("goals"))),
        Sec(title: "خطوات المتابعة", icon: "list.number", color: "indigo", toggle: P("steps", "enabled"), route: .form("steps", P("steps"))),
        Sec(title: "جدول المقارنة", icon: "tablecells", color: "teal", toggle: P("compare", "enabled"), route: .form("compare", P("compare"))),
        Sec(title: "القاعة والموقع", icon: "mappin.and.ellipse", color: "orange", toggle: P("gym", "enabled"), route: .form("gym", P("gym"))),
        Sec(title: "وضع التدريب", icon: "figure.strengthtraining.traditional", color: "purple", toggle: P("train", "enabled"), route: .form("train", P("train"))),
        Sec(title: "معرض النتائج", icon: "photo.on.rectangle", color: "pink", toggle: P("gallery", "enabled"), route: .form("gallery", P("gallery"))),
        Sec(title: "تحديثات المنصة", icon: "sparkles", color: "amber", toggle: P("changelog", "enabled"), route: .form("changelog", P("changelog"))),
        Sec(title: "عدّاد المتصفحين", icon: "person.2.wave.2", color: "steel", toggle: P("visitors", "enabled"), route: .form("visitors", P("visitors"))),
        Sec(title: "بطاقة المطوّر", icon: "signature", color: "graphite", toggle: P("developer", "enabled"), route: .form("developer", P("developer"))),
    ]
    var body: some View {
        Page(title: "أقسام الصفحة الرئيسية", intro: "استخدم المفتاح لإظهار القسم أو إخفائه، واضغط على القسم لتعديل محتواه.", id: "sections") {
            Spacer().frame(height: 10)
            Card {
                ForEach(secs.indices, id: \.self) { i in
                    let s = secs[i]
                    HStack(spacing: 0) {
                        NavigationLink(value: s.route) {
                            RowContent(title: s.title, sub: s.toggle.map { store.v($0).isTrue ? "ظاهر في الموقع" : "مخفي" }, icon: s.icon, color: s.color, chevron: s.toggle == nil)
                        }.buttonStyle(RowPress())
                        if let t = s.toggle {
                            Toggle("", isOn: store.bool(t)).labelsHidden().toggleStyle(SwitchToggleStyle(tint: C.ok)).padding(.trailing, 14)
                                .accessibilityLabel("إظهار " + s.title)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - الصفحات الإضافية
struct PagesView: View {
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        Page(title: "الصفحات الإضافية", intro: "صفحات مستقلة يصل إليها الزائر من أسفل الموقع.", id: "pages") {
            Spacer().frame(height: 10)
            Card {
                let pages: [(String, String, String, String)] = [("about", "من أنا", "person.fill", "blue"), ("terms", "شروط الاشتراك", "doc.plaintext.fill", "graphite"), ("privacy", "سياسة الخصوصية", "lock.doc.fill", "teal")]
                ForEach(pages.indices, id: \.self) { i in
                    let p = pages[i]
                    NavRow(value: AnyHashableRoute.form("page-" + p.0, P("pages", p.0)), title: p.1, sub: "iraqfit.com/" + p.0, icon: p.2, color: p.3,
                           pill: store.v(P("pages", p.0, "enabled")).bool == false ? ("مخفية", "mute") : nil)
                }
            }
        }
    }
}

// MARK: - وضع الموقع
struct ModeView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let mode = store.v(P("mode")).str
        let modes: [(String, String, String, String, String, String)] = [
            ("live", "يعمل", "الموقع متاح لجميع الزوار.", "checkmark.circle.fill", "ok", ""),
            ("maintenance", "صيانة", "تظهر للزائر صفحة صيانة مع موعد العودة إن حدّدته.", "wrench.and.screwdriver.fill", "warn", "mode.maintenance"),
            ("offline", "إيقاف", "تظهر للزائر صفحة خطأ بسيطة. استخدمه بحذر.", "pause.circle.fill", "bad", "mode.offline"),
        ]
        Page(title: "وضع الموقع", intro: "التغيير إجراء حسّاس، ولا يُطبَّق إلا بعد الضغط على «حفظ».", id: "mode") {
            if !store.loaded { LoadingView() } else {
                Spacer().frame(height: 10)
                Card {
                    ForEach(modes.indices, id: \.self) { i in
                        let m = modes[i]
                        if m.5.isEmpty || session.can(m.5) {
                            Button { store.set(P("mode"), .string(m.0)); Haptics.tap() } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: m.3).font(.system(size: 24)).foregroundStyle(C.tone(m.4)).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(m.1).font(.ox(16, .semibold)).foregroundStyle(C.ink)
                                        Text(m.2).font(.ox(12.5)).foregroundStyle(C.mute).lineSpacing(1)
                                    }
                                    Spacer()
                                    Image(systemName: mode == m.0 ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(mode == m.0 ? C.tone(m.4) : C.line)
                                }
                                .padding(14).contentShape(Rectangle())
                            }.buttonStyle(RowPress()).accessibilityIdentifier("mode-" + m.0)
                        }
                    }
                }
                if session.canAny(["mode.maintenance", "mode.offline"]) {
                    SectionTitle("الصفحات التي يراها الزائر")
                    Card {
                        if session.can("mode.maintenance") { NavRow(value: AnyHashableRoute.form("maintenance", P("maintenance")), title: "صفحة الصيانة", sub: "النص وعدّاد العودة", icon: "wrench.and.screwdriver.fill", color: "amber") }
                        if session.can("mode.offline") { NavRow(value: AnyHashableRoute.form("offline", P("offline")), title: "صفحة الإيقاف", sub: "النص ورمز الخطأ", icon: "pause.circle.fill", color: "red") }
                    }
                }
            }
        }
    }
}

// MARK: - البحث في نصوص الموقع
struct TextsView: View {
    @ObservedObject var store = ConfigStore.shared
    @State private var q = ""
    @State private var filter = "all"
    var body: some View {
        let ov = store.v(P("texts", "over")), hd = store.v(P("texts", "hide"))
        let keys = store.ui.keys.filter { k in
            let u = store.ui[k]
            if filter == "mod" && ov[k].isNull { return false }
            if filter == "hid" && !hd["ui." + k].isTrue { return false }
            if q.count < 2 { return true }
            let n = TextsView.norm(q)
            return TextsView.norm(u["oar"].str).contains(n) || TextsView.norm(u["oen"].str).contains(n) || TextsView.norm(ov[k]["ar"].str).contains(n)
        }
        Page(title: "نصوص الموقع", intro: "ابحث عن أي عبارة كما تظهر في الموقع، ثم عدّلها أو أخفِها.", id: "texts") {
            Picker("", selection: $filter) { Text("الكل").tag("all"); Text("المعدّلة").tag("mod"); Text("المخفية").tag("hid") }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 8)
            SectionTitle(keys.count == 1 ? "عبارة واحدة" : "\(Fmt.n(keys.count)) عبارة", trailing: keys.count > 120 ? "يظهر أول 120 — استخدم البحث" : nil)
            Card { ForEach(Array(keys.prefix(120)), id: \.self) { k in UIWordRow(key: k) } }
        }
        .searchable(text: $q, prompt: "ابحث عن عبارة")
    }
    static func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "[\\u064B-\\u065F\\u0670\\u0640]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[أإآ]", with: "ا", options: .regularExpression).replacingOccurrences(of: "ة", with: "ه").replacingOccurrences(of: "ى", with: "ي")
    }
}
struct UIWordRow: View {
    let key: String
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let u = store.ui[key], op: [Seg] = [.key("texts"), .key("over"), .key(key)], ov = store.v(op)
        let hidden = store.v(P("texts", "hide"))["ui." + key].isTrue
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("الأصل: " + u["oar"].str).font(.ox(12)).foregroundStyle(C.mute).lineLimit(1)
                Spacer()
                if !ov.isNull { Pill(text: "معدّلة", tone: "info") }
                if hidden { Pill(text: "مخفية", tone: "warn") }
                Menu {
                    if !ov.isNull { Button { store.set(op, nil) } label: { Label("استعادة النص الأصلي", systemImage: "arrow.uturn.backward") } }
                    Button { store.set([.key("texts"), .key("hide"), .key("ui." + key)], hidden ? nil : .bool(true)) } label: {
                        Label(hidden ? "إظهار العبارة" : "إخفاء العبارة", systemImage: hidden ? "eye" : "eye.slash")
                    }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundStyle(C.mute).frame(width: 32, height: 28) }
            }
            TextField("بالعربية", text: binding("ar", u), axis: .vertical).font(.ox(15)).foregroundStyle(C.ink)
            TextField("English", text: binding("en", u), axis: .vertical).font(.ox(14)).foregroundStyle(C.ink2).environment(\.layoutDirection, .leftToRight)
        }
        .opacity(hidden ? 0.55 : 1)
        .padding(14)
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
