import SwiftUI
import Charts
import MapKit

// MARK: - الزوار والإحصائيات
struct StatsView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/stats?range=7")
    @StateObject private var live = Remote("/live")
    @State private var range = "7"
    @State private var metric = "views"
    @State private var dim = "c"

    var body: some View {
        let t = prefs.theme
        ScrollView {
            VStack(spacing: 14) {
                if session.can("stats") {
                    Chips(options: [("1", "اليوم"), ("yesterday", "أمس"), ("7", "7 أيام"), ("30", "30 يوم"), ("90", "3 أشهر"), ("365", "سنة")], selection: $range)
                        .padding(.horizontal, -16)
                }
                quickLinks
                if session.can("stats") {
                    RemoteBody(r: r) {
                        VStack(spacing: 14) {
                            kpis
                            chart
                            mapCard
                            heatCard
                            dimsCard
                            eventsCard
                        }
                    }
                }
            }
            .padding(16)
        }
        .oxScreen("الزوار", page: "stats")
        .background(t.bg)
        .task { await r.load(); }
        .refreshable { await r.load() }
        .onChange(of: range) { _, v in Task { await r.load("/stats?range=\(v)") } }
    }

    var quickLinks: some View {
        HStack(spacing: 10) {
            if session.can("live") {
                NavigationLink(value: "live") {
                    HStack { PulseDot(color: prefs.theme.ok); Text("هسه بالموقع").font(.ox(14, .semibold)); Spacer(); Image(systemName: "chevron.left").font(.system(size: 12)) }
                        .padding(14).frame(maxWidth: .infinity).background(prefs.theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }.buttonStyle(.plain).accessibilityIdentifier("openLive")
            }
            if session.can("speed") {
                NavigationLink(value: "speed") {
                    HStack { Image(systemName: "gauge.with.dots.needle.67percent").foregroundStyle(prefs.theme.accent); Text("سرعة الموقع").font(.ox(14, .semibold)); Spacer(); Image(systemName: "chevron.left").font(.system(size: 12)) }
                        .padding(14).frame(maxWidth: .infinity).background(prefs.theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }.buttonStyle(.plain).accessibilityIdentifier("openSpeed")
            }
        }.foregroundStyle(prefs.theme.ink)
    }

    func delta(_ k: String) -> (String, String)? {
        let a = r.data["tot"][k].double ?? 0, b = r.data["ptot"][k].double ?? 0
        guard b > 0 else { return nil }
        let p = Int(((a - b) / b * 100).rounded())
        return (p >= 0 ? "▲ \(p)% عن قبلها" : "▼ \(abs(p))% عن قبلها", p >= 0 ? "ok" : "bad")
    }
    var kpis: some View {
        let tot = r.data["tot"]
        return KPIGrid {
            KPI(title: "المشاهدات", value: Fmt.n(tot["views"]), icon: "eye.fill", foot: delta("views")?.0, tone: delta("views")?.1)
            KPI(title: "زوار مختلفين", value: Fmt.n(tot["uniq"]), icon: "person.2.fill", foot: delta("uniq")?.0, tone: delta("uniq")?.1)
            KPI(title: "زوار جدد", value: Fmt.n(tot["new"]), icon: "sparkles", foot: delta("new")?.0, tone: delta("new")?.1)
            KPI(title: "أعلى تواجد سوية", value: Fmt.n(tot["peak"]), icon: "chart.line.uptrend.xyaxis")
        }
    }

    struct DayPoint: Identifiable { let id: String; let date: Date; let v: Double }
    var points: [DayPoint] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = Fmt.baghdad
        return r.data["days"].keys.sorted().compactMap { d in
            guard let dt = f.date(from: d) else { return nil }
            return DayPoint(id: d, date: dt, v: r.data["days"][d][metric].double ?? 0)
        }
    }
    var chart: some View {
        Card(title: "على طول المدة", icon: "chart.xyaxis.line") {
            Picker("", selection: $metric) {
                Text("المشاهدات").tag("views"); Text("الزوار").tag("uniq"); Text("الجدد").tag("new")
            }.pickerStyle(.segmented)
            let pts = points
            if pts.count <= 1 {
                let v = pts.first?.v ?? 0
                Text(Fmt.n(v)).font(.num(40, .bold)).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                Chart(pts) { p in
                    AreaMark(x: .value("اليوم", p.date, unit: .day), y: .value("العدد", p.v))
                        .foregroundStyle(LinearGradient(colors: [prefs.theme.accent.opacity(0.35), prefs.theme.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("اليوم", p.date, unit: .day), y: .value("العدد", p.v))
                        .foregroundStyle(prefs.theme.accent).interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 2.2))
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine().foregroundStyle(prefs.theme.line); AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.ox(10)) } }
                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(prefs.theme.line); AxisValueLabel().font(.num(10, .regular)) } }
                .frame(height: 200)
            }
        }
    }

    struct CityPin: Identifiable { let id: String; let coord: CLLocationCoordinate2D; let n: Double; let name: String; let cc: String }
    var pins: [CityPin] {
        r.data["cities"].arr.compactMap { c in
            guard let la = c["lat"].double, let lo = c["lng"].double else { return nil }
            return CityPin(id: c["cc"].str + c["city"].str, coord: .init(latitude: la, longitude: lo), n: c["n"].double ?? 0, name: cityName(c["city"].str), cc: c["cc"].str)
        }
    }
    @State private var mapWorld = false
    var mapCard: some View {
        let ps = pins, mx = ps.map(\.n).max() ?? 1
        return Card(title: "الخريطة", icon: "map.fill", subtitle: "\(Fmt.n(ps.count)) مدينة", trailing: AnyView(
            Picker("", selection: $mapWorld) { Text("العراق").tag(false); Text("العالم").tag(true) }.pickerStyle(.segmented).frame(width: 150)
        )) {
            Map(position: .constant(mapWorld ? .region(MKCoordinateRegion(center: .init(latitude: 30, longitude: 30), span: .init(latitudeDelta: 100, longitudeDelta: 150))) : .region(MKCoordinateRegion(center: .init(latitude: 33.2, longitude: 43.7), span: .init(latitudeDelta: 9.5, longitudeDelta: 9.5))))) {
                ForEach(ps) { p in
                    Annotation(p.name, coordinate: p.coord) {
                        Circle().fill(prefs.theme.accent.opacity(0.75))
                            .frame(width: 10 + 26 * sqrt(p.n / mx), height: 10 + 26 * sqrt(p.n / mx))
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                            .overlay(Text(Fmt.n(p.n)).font(.num(9, .bold)).foregroundStyle(.white).opacity(p.n / mx > 0.25 ? 1 : 0))
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .id(mapWorld)
            ForEach(Array(r.data["cities"].arr.prefix(8).enumerated()), id: \.offset) { _, c in
                BarRow(name: cityName(c["city"].str.isEmpty ? "غير معروفة" : c["city"].str), value: c["n"].double ?? 0, total: r.data["tot"]["views"].double ?? 1, max: r.data["cities"][0]["n"].double ?? 1, lead: flag(c["cc"].str))
            }
        }
    }

    var heatCard: some View {
        let heat = r.data["heat"].arr.map { $0.arr.map { $0.double ?? 0 } }
        let mx = heat.flatMap { $0 }.max() ?? 0
        let days = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
        return Card(title: "أوقات الذروة", icon: "clock.fill", subtitle: "حسب توقيت بغداد") {
            if mx == 0 { Text("ماكو بيانات كافية بعد").font(.ox(13)).foregroundStyle(prefs.theme.mute) }
            else {
                VStack(spacing: 3) {
                    ForEach(0..<min(7, heat.count), id: \.self) { d in
                        HStack(spacing: 3) {
                            Text(days[d]).font(.ox(9.5)).foregroundStyle(prefs.theme.mute).frame(width: 44, alignment: .leading)
                            ForEach(0..<min(24, heat[d].count), id: \.self) { h in
                                RoundedRectangle(cornerRadius: 2).fill(prefs.theme.accent.opacity(0.06 + 0.94 * heat[d][h] / mx)).frame(height: 14)
                            }
                        }
                    }
                    HStack { Text("12 ص").font(.num(9, .regular)); Spacer(); Text("12 م").font(.num(9, .regular)); Spacer(); Text("11 م").font(.num(9, .regular)) }.foregroundStyle(prefs.theme.mute).padding(.leading, 47)
                }.environment(\.layoutDirection, .leftToRight)
            }
        }
    }

    var dimsCard: some View {
        let names: [(String, String)] = [("c", "الدول"), ("s", "المصدر"), ("d", "الجهاز"), ("o", "النظام"), ("b", "المتصفح"), ("l", "اللغة"), ("p", "الصفحات")]
        let list = r.data["dims"][dim].sortedCounts
        let total = list.reduce(0) { $0 + $1.1 }
        return Card(title: "من وين يجون", icon: "list.bullet.rectangle.fill") {
            Chips(options: names, selection: $dim).padding(.horizontal, -16)
            if list.isEmpty { Text("ماكو بيانات").font(.ox(13)).foregroundStyle(prefs.theme.mute) }
            ForEach(Array(list.prefix(12).enumerated()), id: \.offset) { _, it in
                BarRow(name: dimName(dim, it.0), value: it.1, total: total, max: list.first?.1 ?? 1, lead: dim == "c" ? flag(it.0) : nil)
            }
        }
    }
    func dimName(_ d: String, _ k: String) -> String {
        switch d {
        case "c": return countryName(k)
        case "s": return Labels.sources[k] ?? k
        case "d": return Labels.devices[k] ?? k
        case "o": return Labels.os[k] ?? k
        case "b": return Labels.browsers[k] ?? k
        case "l": return Labels.langs[k] ?? k
        case "p": return Labels.pages[k] ?? k
        default: return k
        }
    }
    var eventsCard: some View {
        let ev = r.data["dims"]["e"]
        return Card(title: "التفاعل", icon: "hand.tap.fill") {
            if ev.keys.isEmpty { Text("ماكو ضغطات بهالمدة").font(.ox(13)).foregroundStyle(prefs.theme.mute) }
            ForEach(ev.sortedCounts.indices, id: \.self) { i in
                let e = ev.sortedCounts[i]
                let prev = r.data["pev"][e.0].double
                HStack {
                    Text(Labels.events[e.0] ?? e.0).font(.ox(14.5))
                    Spacer()
                    if let p = prev, p > 0 { Text("قبلها \(Fmt.n(p))").font(.ox(11.5)).foregroundStyle(prefs.theme.mute) }
                    Text(Fmt.n(e.1)).font(.num(16, .bold))
                }
            }
        }
    }
}

// MARK: - هسه بالموقع
struct LiveView: View {
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/live")
    var body: some View {
        let t = prefs.theme
        List {
            Section {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) { PulseDot(color: t.ok); Text("هسه").font(.ox(13)).foregroundStyle(t.mute) }
                        Text(Fmt.n(r.data["now"])).font(.num(44, .bold)).contentTransition(.numericText()).accessibilityIdentifier("liveNow")
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("آخر ساعة").font(.ox(13)).foregroundStyle(t.mute)
                        Text(Fmt.n(r.data["hour"])).font(.num(26, .semibold))
                    }
                }.padding(.vertical, 6)
            } footer: { Text("يتحدث كل 10 ثواني").font(.ox(12)) }
            Section("المتصفحين") {
                if r.data["list"].arr.isEmpty { Text("ماكو أحد هسه").font(.ox(14)).foregroundStyle(t.mute) }
                ForEach(Array(r.data["list"].arr.enumerated()), id: \.offset) { _, v in LiveVisitorRow(v: v) }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: r.data)
        .oxScreen("هسه بالموقع", page: "live")
        .task { await r.load(); r.every(10) }
        .onDisappear { r.stop() }
        .refreshable { await r.load() }
    }
}
struct LiveVisitorRow: View {
    let v: JSON
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        HStack(spacing: 12) {
            Text(flag(v["cc"].str)).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 3) {
                Text([cityName(v["city"].str), countryName(v["cc"].str)].filter { !$0.isEmpty }.joined(separator: "، ")).font(.ox(14.5, .medium))
                HStack(spacing: 6) {
                    Image(systemName: v["dev"].str == "desk" ? "desktopcomputer" : v["dev"].str == "tab" ? "ipad" : "iphone").font(.system(size: 11))
                    Text([Labels.os[v["os"].str] ?? v["os"].str, Labels.browsers[v["br"].str] ?? v["br"].str, Labels.sources[v["src"].str] ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.ox(12))
                }.foregroundStyle(prefs.theme.mute)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.dur(Date().timeIntervalSince(v["since"].date ?? v["last"].date ?? Date()))).font(.num(12, .medium))
                Text(Labels.pages[v["page"].str] ?? v["page"].str).font(.ox(11)).foregroundStyle(prefs.theme.mute).lineLimit(1)
            }
        }
    }
}

// MARK: - سرعة الموقع
struct SpeedView: View {
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/speed?hours=24")
    @State private var hours = "24"
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Chips(options: [("1", "ساعة"), ("24", "يوم"), ("168", "أسبوع"), ("720", "شهر")], selection: $hours).padding(.horizontal, -16)
                RemoteBody(r: r) {
                    VStack(spacing: 14) {
                        gaugeCard
                        regions
                        if r.data["series"].arr.count > 1 { seriesCard }
                        if !r.data["sinceChange"].isNull { changeCard }
                        devicesCard
                        Text("القياس من زوار حقيقيين (p75): يعني 75% من الزوار شافوا الموقع بهالسرعة أو أسرع. LCP = وقت ظهور أكبر شي بالصفحة.").font(.ox(12)).foregroundStyle(prefs.theme.mute)
                    }
                }
            }.padding(16)
        }
        .oxScreen("سرعة الموقع", page: "speed")
        .task { await r.load(); r.every(60) }
        .onDisappear { r.stop() }
        .refreshable { await r.load() }
        .onChange(of: hours) { _, h in Task { await r.load("/speed?hours=\(h)") } }
    }
    func color(_ score: Double?) -> Color {
        guard let s = score else { return prefs.theme.mute }
        return s >= 90 ? prefs.theme.ok : s >= 50 ? prefs.theme.warn : prefs.theme.bad
    }
    var gaugeCard: some View {
        let iq = r.data["iraq"], all = r.data["all"]
        let use = (iq["n"].int ?? 0) > 0 ? iq : all
        let s = use["score"].double
        return Card(title: (iq["n"].int ?? 0) > 0 ? "زوار العراق" : "كل الزوار", icon: "gauge.with.dots.needle.67percent", subtitle: "\(Fmt.n(use["n"])) قياس") {
            HStack(spacing: 20) {
                Gauge(value: s ?? 0, in: 0...100) {
                    Text("")
                } currentValueLabel: {
                    Text(s.map { "\(Int($0))" } ?? "—").font(.num(24, .bold))
                }
                .gaugeStyle(.accessoryCircular).tint(color(s)).scaleEffect(1.7).frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 8) {
                    metric("ظهور المحتوى (LCP)", use["lcp"].double, good: 2500, poor: 4000)
                    metric("أول استجابة (TTFB)", use["ttfb"].double, good: 800, poor: 1800)
                    metric("أول رسم (FCP)", use["fcp"].double, good: 1800, poor: 3000)
                }
            }
            if use["n"].int == 0 { Text("ما وصلت قياسات بعد. القياس يبدأ تلقائيًا من زيارات الناس بعد ما تنشر الكود الجديد.").font(.ox(12.5)).foregroundStyle(prefs.theme.mute) }
        }
    }
    func metric(_ name: String, _ v: Double?, good: Double, poor: Double) -> some View {
        let c: Color = v == nil ? prefs.theme.mute : v! <= good ? prefs.theme.ok : v! <= poor ? prefs.theme.warn : prefs.theme.bad
        return VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.ox(11.5)).foregroundStyle(prefs.theme.mute)
            Text(Fmt.ms(v)).font(.num(16, .semibold)).foregroundStyle(c)
        }
    }
    var regions: some View {
        KPIGrid {
            let regs: [(String, String, String)] = [("iraq", "العراق", "🇮🇶"), ("region", "المنطقة", "🌍"), ("world", "باقي العالم", "🌐")]
            ForEach(regs.indices, id: \.self) { ri in let k = regs[ri]
                let d = r.data[k.0]
                KPI(title: k.2 + " " + k.1, value: d["score"].double.map { "\(Int($0))" } ?? "—", icon: "speedometer", foot: "LCP " + Fmt.ms(d["lcp"].double) + " · \(Fmt.n(d["n"])) قياس", tone: d["score"].double.map { $0 >= 90 ? "ok" : $0 >= 50 ? "warn" : "bad" })
            }
        }
    }
    struct SP: Identifiable { let id: Double; let at: Date; let lcp: Double }
    var seriesCard: some View {
        let pts = r.data["series"].arr.compactMap { s -> SP? in
            guard let at = s["at"].double, let l = s["lcp"].double else { return nil }
            return SP(id: at, at: Date(timeIntervalSince1970: at / 1000), lcp: l)
        }
        return Card(title: "LCP على طول الوقت", icon: "waveform.path.ecg") {
            Chart {
                RuleMark(y: .value("جيد", 2500)).foregroundStyle(prefs.theme.ok.opacity(0.5)).lineStyle(StrokeStyle(dash: [4]))
                ForEach(pts) { p in
                    LineMark(x: .value("الوقت", p.at), y: .value("LCP", p.lcp)).foregroundStyle(prefs.theme.accent).interpolationMethod(.monotone)
                    PointMark(x: .value("الوقت", p.at), y: .value("LCP", p.lcp)).foregroundStyle(p.lcp <= 2500 ? prefs.theme.ok : p.lcp <= 4000 ? prefs.theme.warn : prefs.theme.bad).symbolSize(18)
                }
            }
            .chartYAxis { AxisMarks { v in AxisGridLine().foregroundStyle(prefs.theme.line); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.ms(d)).font(.num(9, .regular)) } } } }
            .frame(height: 180)
        }
    }
    var changeCard: some View {
        let c = r.data["sinceChange"]
        let b = c["before"]["lcp"].double, a = c["after"]["lcp"].double
        return Card(title: "قبل وبعد آخر تعديل", icon: "arrow.left.arrow.right", subtitle: c["what"].str + " · " + Fmt.ago(c["at"].date)) {
            HStack {
                VStack { Text("قبل").font(.ox(12)).foregroundStyle(prefs.theme.mute); Text(Fmt.ms(b)).font(.num(20, .bold)) }.frame(maxWidth: .infinity)
                Image(systemName: "arrow.left").foregroundStyle(prefs.theme.mute)
                VStack { Text("بعد").font(.ox(12)).foregroundStyle(prefs.theme.mute); Text(Fmt.ms(a)).font(.num(20, .bold)).foregroundStyle(a != nil && b != nil ? (a! <= b! ? prefs.theme.ok : prefs.theme.bad) : prefs.theme.ink) }.frame(maxWidth: .infinity)
            }
            if let a, let b, b > 0 {
                let p = Int(((a - b) / b * 100).rounded())
                Text(p <= 0 ? "صار أسرع بـ \(abs(p))%" : "صار أبطأ بـ \(p)% — شيك آخر تعديل").font(.ox(13, .medium)).foregroundStyle(p <= 0 ? prefs.theme.ok : prefs.theme.warn)
            }
        }
    }
    var devicesCard: some View {
        let dv = r.data["devices"]
        return Card(title: "حسب الجهاز", icon: "iphone") {
            ForEach(dv.keys, id: \.self) { k in
                InfoRow(title: Labels.devices[k] ?? k, value: "LCP " + Fmt.ms(dv[k]["lcp"].double) + " · \(Fmt.n(dv[k]["n"]))")
            }
            if dv.keys.isEmpty { Text("ماكو بيانات").font(.ox(13)).foregroundStyle(prefs.theme.mute) }
        }
    }
}
