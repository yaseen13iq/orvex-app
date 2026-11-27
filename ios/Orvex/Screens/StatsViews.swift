import SwiftUI
import Charts
import MapKit

// MARK: - تبويب «الإحصاءات»
struct StatsView: View {
    @EnvironmentObject var session: Session
    @StateObject private var r = Remote("/stats?range=7")
    @State private var range = "7"
    @State private var metric = "views"
    @State private var dim = "c"
    var body: some View {
        Page(title: "الإحصاءات", intro: "زوار الموقع ومن أين أتوا، بتوقيت بغداد.", id: "stats") {
            if session.canAny(["live", "speed"]) {
                Spacer().frame(height: 6)
                Card {
                    if session.can("live") { NavRow(value: "live", title: "المتصفحون الآن", sub: "من يتصفح الموقع في هذه اللحظة", icon: "dot.radiowaves.left.and.right", color: "green", trailing: Fmt.n(session.status["live"])) }
                    if session.can("speed") { NavRow(value: "speed", title: "سرعة الموقع", sub: "قياس حقيقي من أجهزة الزوار", icon: "gauge.with.dots.needle.67percent", color: "blue") }
                }
            }
            if session.can("stats") {
                SectionTitle("الفترة")
                Chips(options: [("1", "اليوم"), ("yesterday", "أمس"), ("7", "7 أيام"), ("30", "30 يومًا"), ("90", "3 أشهر"), ("365", "سنة")], selection: $range)
                RemoteBody(r: r) {
                    VStack(spacing: 0) {
                        SectionTitle("الملخّص")
                        KPIGrid {
                            KPI(title: "الزيارات", value: Fmt.n(r.data["tot"]["views"]), foot: delta("views")?.0, tone: delta("views")?.1)
                            KPI(title: "الزوار", value: Fmt.n(r.data["tot"]["uniq"]), foot: delta("uniq")?.0, tone: delta("uniq")?.1)
                            KPI(title: "زوار جدد", value: Fmt.n(r.data["tot"]["new"]), foot: delta("new")?.0, tone: delta("new")?.1)
                            KPI(title: "أعلى تواجد متزامن", value: Fmt.n(r.data["tot"]["peak"]))
                        }
                        chart
                        mapCard
                        dims
                        events
                    }
                }
            }
        }
        .task { if session.can("stats") { await r.load() } }
        .refreshable { await r.load(); await session.refreshStatus() }
        .onChange(of: range) { _, v in Task { await r.load("/stats?range=\(v)") } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: "search") { Image(systemName: "magnifyingglass") }.accessibilityLabel("البحث") } }
    }

    func delta(_ k: String) -> (String, String)? {
        let a = r.data["tot"][k].double ?? 0, b = r.data["ptot"][k].double ?? 0
        guard b > 0 else { return nil }
        let p = Int(((a - b) / b * 100).rounded())
        return p >= 0 ? ("▲ \(Fmt.n(p))٪ عن الفترة السابقة", "ok") : ("▼ \(Fmt.n(abs(p)))٪ عن الفترة السابقة", "bad")
    }

    struct DayPoint: Identifiable { let id: String; let date: Date; let v: Double }
    var points: [DayPoint] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = Fmt.baghdad
        return r.data["days"].keys.sorted().compactMap { d in
            guard let dt = f.date(from: d) else { return nil }
            return DayPoint(id: d, date: dt, v: r.data["days"][d][metric].double ?? 0)
        }
    }
    @ViewBuilder var chart: some View {
        let pts = points
        if pts.count > 1 {
            SectionTitle("على مدار الفترة")
            Card(padded: true) {
                VStack(spacing: 14) {
                    Picker("", selection: $metric) { Text("الزيارات").tag("views"); Text("الزوار").tag("uniq"); Text("الجدد").tag("new") }.pickerStyle(.segmented)
                    Chart(pts) { p in
                        AreaMark(x: .value("اليوم", p.date, unit: .day), y: .value("العدد", p.v))
                            .foregroundStyle(LinearGradient(colors: [C.info.opacity(0.3), C.info.opacity(0.02)], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                        LineMark(x: .value("اليوم", p.date, unit: .day), y: .value("العدد", p.v))
                            .foregroundStyle(C.info).interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 2.2))
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine().foregroundStyle(C.line); AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.ox(10)) } }
                    .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(C.line); AxisValueLabel().font(.ox(10)) } }
                    .frame(height: 190)
                }
            }
        }
    }

    struct Pin: Identifiable { let id: String; let c: CLLocationCoordinate2D; let n: Double; let name: String }
    @ViewBuilder var mapCard: some View {
        let cities = r.data["cities"].arr
        let pins = cities.compactMap { c -> Pin? in
            guard let la = c["lat"].double, let lo = c["lng"].double else { return nil }
            return Pin(id: c["cc"].str + c["city"].str, c: .init(latitude: la, longitude: lo), n: c["n"].double ?? 0, name: cityName(c["city"].str))
        }
        if !cities.isEmpty {
            let mx = pins.map(\.n).max() ?? 1
            SectionTitle("المدن")
            VStack(spacing: 10) {
                if !pins.isEmpty {
                    Map(initialPosition: .region(MKCoordinateRegion(center: .init(latitude: 33.2, longitude: 43.7), span: .init(latitudeDelta: 9.5, longitudeDelta: 9.5)))) {
                        ForEach(pins) { p in
                            Annotation(p.name, coordinate: p.c) {
                                Circle().fill(C.info.opacity(0.8)).frame(width: 10 + 24 * sqrt(p.n / mx), height: 10 + 24 * sqrt(p.n / mx)).overlay(Circle().stroke(.white, lineWidth: 1.5))
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 250).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).padding(.horizontal, 16)
                }
                Card {
                    ForEach(Array(cities.prefix(8).enumerated()), id: \.offset) { _, c in
                        BarRow(name: cityName(c["city"].str), value: c["n"].double ?? 0, total: r.data["tot"]["views"].double ?? 1, max: cities.first?["n"].double ?? 1, lead: flag(c["cc"].str))
                    }
                }
            }
        }
    }

    var dims: some View {
        let names: [(String, String)] = [("c", "الدول"), ("s", "مصدر الزيارة"), ("d", "نوع الجهاز"), ("o", "نظام التشغيل"), ("b", "المتصفح"), ("p", "الصفحات")]
        let list = r.data["dims"][dim].counts
        let total = list.reduce(0) { $0 + $1.n }
        return VStack(spacing: 0) {
            SectionTitle("التفاصيل")
            Chips(options: names, selection: $dim).padding(.bottom, 10)
            Card {
                if list.isEmpty { Text("لا توجد بيانات لهذه الفترة.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                ForEach(Array(list.prefix(10).enumerated()), id: \.offset) { _, it in
                    BarRow(name: name(dim, it.key), value: it.n, total: total, max: list.first?.n ?? 1, lead: dim == "c" ? flag(it.key) : nil)
                }
            }
        }
    }
    func name(_ d: String, _ k: String) -> String {
        switch d {
        case "c": return countryName(k)
        case "s": return Names.sources[k] ?? k
        case "d": return Names.devices[k] ?? k
        case "o": return Names.os[k] ?? k
        case "b": return Names.browsers[k] ?? k
        case "p": return Names.pages[k] ?? k
        default: return k
        }
    }
    @ViewBuilder var events: some View {
        let ev = r.data["dims"]["e"].counts
        if !ev.isEmpty {
            SectionTitle("تفاعل الزوار")
            Card {
                ForEach(Array(ev.prefix(10).enumerated()), id: \.offset) { _, e in
                    InfoRow(title: Names.events[e.key] ?? e.key, value: Fmt.n(e.n))
                }
            }
        }
    }
}

// MARK: - المتصفحون الآن
struct LiveView: View {
    @StateObject private var r = Remote("/live")
    var body: some View {
        Page(title: "المتصفحون الآن", intro: "يُحدَّث تلقائيًا كل 10 ثوانٍ.", id: "live") {
            Spacer().frame(height: 6)
            KPIGrid {
                KPI(title: "الآن", value: Fmt.n(r.data["now"]), foot: "خلال آخر 5 دقائق", tone: "ok")
                KPI(title: "آخر ساعة", value: Fmt.n(r.data["hour"]))
            }
            SectionTitle("الزوار")
            Card {
                if r.loaded && r.data["list"].arr.isEmpty { Text("لا يوجد أحد يتصفح الموقع الآن.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                ForEach(Array(r.data["list"].arr.enumerated()), id: \.offset) { _, v in
                    HStack(spacing: 12) {
                        Text(flag(v["cc"].str)).font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 3) {
                            Text([cityName(v["city"].str), countryName(v["cc"].str)].joined(separator: "، ")).font(.ox(15, .medium)).foregroundStyle(C.ink)
                            Text([Names.devices[v["dev"].str] ?? "", Names.os[v["os"].str] ?? "", Names.sources[v["src"].str] ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.ox(12)).foregroundStyle(C.mute)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.dur(Date().timeIntervalSince(v["since"].date ?? v["last"].date ?? Date()))).font(.ox(13, .semibold)).foregroundStyle(C.ink)
                            Text(Names.pages[v["page"].str] ?? v["page"].str).font(.ox(11)).foregroundStyle(C.mute).lineLimit(1)
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 11)
                }
            }
        }
        .task { await r.load(); r.every(10) }
        .onDisappear { r.stop() }
        .refreshable { await r.load() }
    }
}

// MARK: - سرعة الموقع
struct SpeedView: View {
    @StateObject private var r = Remote("/speed?hours=24")
    @State private var hours = "24"
    var body: some View {
        Page(title: "سرعة الموقع", intro: "قياس حقيقي من أجهزة الزوار: 75٪ من الزوار رأوا الموقع بهذه السرعة أو أسرع.", id: "speed") {
            Spacer().frame(height: 6)
            Chips(options: [("1", "آخر ساعة"), ("24", "آخر يوم"), ("168", "آخر أسبوع"), ("720", "آخر شهر")], selection: $hours)
            RemoteBody(r: r) {
                VStack(spacing: 0) {
                    SectionTitle("حسب المنطقة")
                    Card {
                        let regs: [(String, String)] = [("iraq", "🇮🇶  العراق"), ("region", "🌍  دول المنطقة"), ("world", "🌐  باقي العالم")]
                        ForEach(regs.indices, id: \.self) { i in row(regs[i].1, r.data[regs[i].0]) }
                    }
                    SectionFooter("الدرجة من 100. التحميل الجيد أقل من 2.5 ثانية.")
                    if !r.data["sinceChange"].isNull {
                        let c = r.data["sinceChange"], b = c["before"]["lcp"].double, a = c["after"]["lcp"].double
                        SectionTitle("قبل آخر تعديل وبعده")
                        Card {
                            InfoRow(title: "قبل", value: Fmt.ms(b))
                            InfoRow(title: "بعد", value: Fmt.ms(a), tone: a != nil && b != nil ? (a! <= b! ? "ok" : "bad") : nil)
                            InfoRow(title: "التعديل", value: c["what"].str)
                        }
                    }
                    if (r.data["all"]["n"].int ?? 0) == 0 {
                        Spacer().frame(height: 12)
                        Note(text: "لم تصل قياسات بعد. يبدأ القياس تلقائيًا مع زيارات الناس للموقع.", tone: "info")
                    }
                }
            }
        }
        .task { await r.load() }
        .refreshable { await r.load() }
        .onChange(of: hours) { _, h in Task { await r.load("/speed?hours=\(h)") } }
    }
    func row(_ name: String, _ d: JSON) -> some View {
        let s = d["score"].double
        let tone = s == nil ? "mute" : s! >= 90 ? "ok" : s! >= 50 ? "warn" : "bad"
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.ox(15.5, .medium)).foregroundStyle(C.ink)
                Text("ظهور المحتوى \(Fmt.ms(d["lcp"].double)) · \(Fmt.n(d["n"])) قياس").font(.ox(12)).foregroundStyle(C.mute)
            }
            Spacer()
            Text(s.map { Fmt.n($0.rounded()) } ?? "—").font(.num(22)).foregroundStyle(C.tone(tone))
                .frame(width: 58, height: 44).background(C.toneBG(tone), in: RoundedRectangle(cornerRadius: 12))
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}
