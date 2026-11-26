import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - البيانات
struct StatusEntry: TimelineEntry {
    let date: Date
    let s: JSON?
    let prefs: WidgetPrefs
    var signedIn: Bool { s != nil }
}

struct StatusProvider: TimelineProvider {
    static let sample: JSON = ["health": "ok", "mode": "live", "version": "3.4.1", "live": 12, "waitlist": 87,
                               "gate": ["state": "soon", "label": "تفتح قريبًا"], "today": ["views": 1240, "uniq": 610, "cta": 44, "rem": 19], "problems": []]
    func placeholder(in context: Context) -> StatusEntry { StatusEntry(date: .now, s: StatusProvider.sample, prefs: WidgetPrefs()) }
    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(StatusEntry(date: .now, s: await StatusFetcher.fetch(), prefs: WidgetPrefs.load())) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let s = await StatusFetcher.fetch()
            let e = StatusEntry(date: .now, s: s, prefs: WidgetPrefs.load())
            completion(Timeline(entries: [e], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }
}

// MARK: - الألوان
struct WPal {
    let bg: Color, ink: Color, mute: Color, line: Color
    static let ok = Color(red: 0.24, green: 0.84, blue: 0.55), warn = Color(red: 0.94, green: 0.71, blue: 0.30), bad = Color(red: 0.94, green: 0.38, blue: 0.42), info = Color(red: 0.49, green: 0.65, blue: 0.94)
    static func of(_ p: WidgetPrefs, _ scheme: ColorScheme) -> WPal {
        let dark = p.theme == "dark" || (p.theme == "auto" && scheme == .dark)
        return dark ? WPal(bg: Color(red: 0.043, green: 0.047, blue: 0.055), ink: .white, mute: Color(red: 0.54, green: 0.57, blue: 0.61), line: .white.opacity(0.08))
                    : WPal(bg: Color(red: 0.933, green: 0.941, blue: 0.953), ink: Color(red: 0.043, green: 0.047, blue: 0.055), mute: Color(red: 0.37, green: 0.40, blue: 0.45), line: .black.opacity(0.08))
    }
    static func health(_ h: String) -> Color { h == "ok" ? ok : h == "maintenance" || h == "warn" ? warn : h == "down" ? bad : info }
    static func level(_ l: String) -> Color { ["ok": ok, "warn": warn, "bad": bad, "info": info][l] ?? info }
}
func wn(_ j: JSON, _ hide: Bool) -> String {
    if hide { return "••" }
    guard let v = j.double else { return "—" }
    if v >= 10000 { return String(format: "%.1fK", v / 1000) }
    return String(Int(v))
}
func healthText(_ s: JSON) -> String {
    switch s["health"].str { case "ok": return "يعمل"; case "maintenance": return "صيانة"; case "down": return "متوقف"; case "warn": return "تنبيه"; default: return "—" }
}

struct Symbol: View {
    var size: CGFloat = 18
    var color: Color
    var body: some View { Image("OrvexSymbol").resizable().renderingMode(.template).scaledToFit().frame(width: size, height: size).foregroundStyle(color) }
}

// MARK: - ويدجت الحالة
struct StatusWidgetView: View {
    let e: StatusEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let p = e.prefs, c = WPal.of(p, scheme)
        Group {
            if let s = e.s {
                switch family {
                case .accessoryCircular: circular(s)
                case .accessoryRectangular: rectangular(s)
                case .accessoryInline: Text("\(healthText(s)) · \(s["gate"]["label"].text)")
                case .systemMedium: medium(s, c)
                case .systemLarge: large(s, c)
                default: small(s, c)
                }
            } else {
                VStack(spacing: 6) {
                    Symbol(size: 26, color: c.ink)
                    Text("افتح أورفيكس وسجّل دخول").font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center).foregroundStyle(c.mute)
                }
            }
        }
        .containerBackground(for: .widget) { c.bg }
        .widgetURL(URL(string: "orvex://home"))
        .environment(\.layoutDirection, .rightToLeft)
    }

    func header(_ s: JSON, _ c: WPal) -> some View {
        HStack(spacing: 6) {
            Symbol(size: 16, color: c.ink)
            Text(healthText(s)).font(.system(size: 12, weight: .semibold)).foregroundStyle(c.ink)
            Spacer(minLength: 0)
            Circle().fill(WPal.health(s["health"].str)).frame(width: 8, height: 8)
        }
    }
    func stat(_ v: String, _ k: String, _ c: WPal, big: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(v).font(.system(size: big ? 28 : 20, weight: .bold, design: .rounded)).foregroundStyle(c.ink).minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText())
            Text(k).font(.system(size: 10, weight: .medium)).foregroundStyle(c.mute)
        }
    }
    func small(_ s: JSON, _ c: WPal) -> some View {
        let p = e.prefs
        return VStack(alignment: .leading, spacing: 4) {
            header(s, c)
            Spacer(minLength: 0)
            if p.showGate { Text(s["gate"]["label"].text).font(.system(size: 15, weight: .bold)).foregroundStyle(c.ink).lineLimit(1) }
            HStack(spacing: 12) {
                if p.showLive && !s["live"].isNull { stat(wn(s["live"], p.hideSensitive), "هسه", c) }
                if p.showVisits && !s["today"].isNull { stat(wn(s["today"]["views"], p.hideSensitive), "اليوم", c) }
                if !p.showLive && !p.showVisits && p.showWaitlist && !s["waitlist"].isNull { stat(wn(s["waitlist"], p.hideSensitive), "منتظر", c) }
            }
        }
    }
    func medium(_ s: JSON, _ c: WPal) -> some View {
        let p = e.prefs
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                header(s, c)
                if p.showVersion { Text("v" + s["version"].str).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(c.mute) }
            }
            if p.showGate {
                HStack(spacing: 6) {
                    Image(systemName: s["gate"]["state"].str == "open" ? "lock.open.fill" : "lock.fill").font(.system(size: 11)).foregroundStyle(c.mute)
                    Text("الاشتراكات: " + s["gate"]["label"].text).font(.system(size: 13, weight: .semibold)).foregroundStyle(c.ink).lineLimit(1)
                    if let at = s["schedule"]["next"]["at"].date, at > .now { Text(at, style: .relative).font(.system(size: 11)).foregroundStyle(c.mute).lineLimit(1) }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                if p.showLive && !s["live"].isNull { stat(wn(s["live"], p.hideSensitive), "هسه بالموقع", c).frame(maxWidth: .infinity, alignment: .leading) }
                if p.showVisits && !s["today"].isNull { stat(wn(s["today"]["views"], p.hideSensitive), "زيارة اليوم", c).frame(maxWidth: .infinity, alignment: .leading) }
                if p.showVisits && !s["today"].isNull { stat(wn(s["today"]["cta"], p.hideSensitive), "ضغطة اشتراك", c).frame(maxWidth: .infinity, alignment: .leading) }
                if p.showWaitlist && !s["waitlist"].isNull { stat(wn(s["waitlist"], p.hideSensitive), "منتظر", c).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }
    }
    func large(_ s: JSON, _ c: WPal) -> some View {
        let p = e.prefs
        return VStack(alignment: .leading, spacing: 12) {
            medium(s, c).frame(maxHeight: 130)
            Divider().overlay(c.line)
            if !s["problems"].arr.isEmpty {
                ForEach(Array(s["problems"].arr.prefix(3).enumerated()), id: \.offset) { _, pr in
                    Label(pr["t"].str, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(WPal.warn).lineLimit(2)
                }
            } else {
                Label("ماكو مشاكل", systemImage: "checkmark.seal.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(WPal.ok)
            }
            if p.showVisits && !s["today"].isNull {
                HStack {
                    stat(wn(s["today"]["uniq"], p.hideSensitive), "زائر مختلف", c).frame(maxWidth: .infinity, alignment: .leading)
                    stat(wn(s["today"]["new"], p.hideSensitive), "زائر جديد", c).frame(maxWidth: .infinity, alignment: .leading)
                    stat(wn(s["today"]["rem"], p.hideSensitive), "«ذكّرني»", c).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
            Text("آخر تحديث ") .font(.system(size: 10)).foregroundStyle(c.mute) + Text(e.date, style: .time).font(.system(size: 10)).foregroundStyle(c.mute)
        }
    }
    func circular(_ s: JSON) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(e.prefs.showLive ? wn(s["live"], e.prefs.hideSensitive) : healthText(s)).font(.system(size: 16, weight: .bold, design: .rounded)).minimumScaleFactor(0.5)
                Text(e.prefs.showLive ? "هسه" : "الموقع").font(.system(size: 9))
            }
        }.widgetAccentable()
    }
    func rectangular(_ s: JSON) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) { Image(systemName: s["health"].str == "ok" ? "checkmark.circle.fill" : "exclamationmark.circle.fill"); Text("أورفيكس · " + healthText(s)).font(.system(size: 13, weight: .semibold)) }
            Text(s["gate"]["label"].text).font(.system(size: 12))
            Text("\(wn(s["live"], e.prefs.hideSensitive)) هسه · \(wn(s["today"]["views"], e.prefs.hideSensitive)) اليوم").font(.system(size: 11))
        }.widgetAccentable()
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "status", provider: StatusProvider()) { StatusWidgetView(e: $0) }
            .configurationDisplayName("حالة الموقع")
            .description("حالة iraqfit.com والاشتراكات والزوار")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - ويدجت الزيارات
struct VisitsWidgetView: View {
    let e: StatusEntry
    @Environment(\.colorScheme) var scheme
    @Environment(\.widgetFamily) var family
    var body: some View {
        let c = WPal.of(e.prefs, scheme), h = e.prefs.hideSensitive
        Group {
            if let s = e.s, !s["today"].isNull {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Image(systemName: "chart.bar.fill").font(.system(size: 12)).foregroundStyle(c.mute); Text("زوار اليوم").font(.system(size: 12, weight: .semibold)).foregroundStyle(c.ink); Spacer() }
                    Spacer(minLength: 0)
                    Text(wn(s["today"]["views"], h)).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(c.ink).minimumScaleFactor(0.5)
                    HStack(spacing: 10) {
                        Label(wn(s["today"]["uniq"], h), systemImage: "person.fill")
                        Label(wn(s["live"], h), systemImage: "dot.radiowaves.left.and.right")
                        if family == .systemMedium { Label(wn(s["today"]["new"], h) + " جديد", systemImage: "sparkles"); Label(wn(s["today"]["cta"], h) + " ضغطة", systemImage: "hand.tap.fill") }
                    }.font(.system(size: 11, weight: .medium)).foregroundStyle(c.mute)
                }
            } else {
                VStack(spacing: 6) { Symbol(size: 24, color: c.ink); Text("ما عندك صلاحية الزوار أو ما سجّلت دخول").font(.system(size: 11)).multilineTextAlignment(.center).foregroundStyle(c.mute) }
            }
        }
        .containerBackground(for: .widget) { c.bg }
        .widgetURL(URL(string: "orvex://stats"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
struct VisitsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "visits", provider: StatusProvider()) { VisitsWidgetView(e: $0) }
            .configurationDisplayName("الزيارات")
            .description("زيارات اليوم والمتصفحين هسه")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - ويدجت المحتوى والاشتراكات
struct GateWidgetView: View {
    let e: StatusEntry
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let c = WPal.of(e.prefs, scheme)
        Group {
            if let s = e.s {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Image(systemName: s["gate"]["state"].str == "open" ? "lock.open.fill" : "lock.fill").foregroundStyle(s["gate"]["state"].str == "open" ? WPal.ok : c.mute); Text("الاشتراكات").font(.system(size: 12, weight: .semibold)).foregroundStyle(c.ink); Spacer() }
                    Spacer(minLength: 0)
                    Text(s["gate"]["label"].text).font(.system(size: 18, weight: .bold)).foregroundStyle(c.ink).lineLimit(2)
                    if let at = s["schedule"]["next"]["at"].date, at > .now {
                        Text(s["schedule"]["next"]["kind"].str == "open" ? "تنفتح بعد" : "تنسد بعد").font(.system(size: 10)).foregroundStyle(c.mute)
                        Text(timerInterval: Date.now...at, countsDown: true).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(c.ink).monospacedDigit()
                    } else if !s["waitlist"].isNull {
                        Text("\(wn(s["waitlist"], e.prefs.hideSensitive)) منتظر بالتيليجرام").font(.system(size: 12)).foregroundStyle(c.mute)
                    }
                }
            } else { Symbol(size: 26, color: c.ink) }
        }
        .containerBackground(for: .widget) { c.bg }
        .widgetURL(URL(string: "orvex://gate"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
struct GateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "gate", provider: StatusProvider()) { GateWidgetView(e: $0) }
            .configurationDisplayName("الاشتراكات")
            .description("حالة الاشتراكات وعدّاد الفتح")
            .supportedFamilies([.systemSmall])
    }
}

// MARK: - الجزيرة التفاعلية وقفل الشاشة
struct OrvexLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrvexActivityAttributes.self) { ctx in
            LockScreenLive(st: ctx.state)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "orvex://home"))
        } dynamicIsland: { ctx in
            let st = ctx.state, col = WPal.level(st.level)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) { Symbol(size: 20, color: .white); Circle().fill(col).frame(width: 8, height: 8) }.padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) { LiveTrailing(st: st, big: true).padding(.trailing, 4) }
                DynamicIslandExpandedRegion(.center) {
                    Text(st.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(st.detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                        if let p = st.progress { ProgressView(value: p).tint(col) }
                        else if let a = st.startedAt, let e = st.endsAt, e > a { ProgressView(timerInterval: a...e, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }.tint(col) }
                    }.frame(maxWidth: .infinity, alignment: .leading).environment(\.layoutDirection, .rightToLeft)
                }
            } compactLeading: {
                HStack(spacing: 4) { Symbol(size: 14, color: .white); Circle().fill(col).frame(width: 6, height: 6) }
            } compactTrailing: {
                LiveTrailing(st: st, big: false)
            } minimal: {
                ZStack { Circle().fill(col.opacity(0.25)); Symbol(size: 12, color: col) }
            }
            .widgetURL(URL(string: "orvex://home"))
            .keylineTint(col)
        }
    }
}

struct LiveTrailing: View {
    let st: OrvexActivityAttributes.ContentState
    let big: Bool
    var body: some View {
        let col = WPal.level(st.level)
        if let e = st.endsAt, e > .now {
            Text(timerInterval: Date.now...e, countsDown: true).font(.system(size: big ? 16 : 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(col).frame(maxWidth: big ? 90 : 52)
        } else if let s = st.startedAt, st.kind == "task" && st.progress == nil {
            Text(timerInterval: s...Date.distantFuture, countsDown: false).font(.system(size: big ? 16 : 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(col).frame(maxWidth: big ? 90 : 52)
        } else if let p = st.progress {
            Text("\(Int(p * 100))%").font(.system(size: big ? 16 : 13, weight: .bold, design: .rounded)).foregroundStyle(col)
        } else if let l = st.live {
            HStack(spacing: 3) { Image(systemName: "person.fill").font(.system(size: big ? 12 : 10)); Text("\(l)").font(.system(size: big ? 16 : 13, weight: .bold, design: .rounded)) }.foregroundStyle(col)
        } else {
            Image(systemName: st.level == "ok" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(col)
        }
    }
}

struct LockScreenLive: View {
    let st: OrvexActivityAttributes.ContentState
    var body: some View {
        let col = WPal.level(st.level)
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)).frame(width: 46, height: 46)
                Symbol(size: 26, color: .white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) { Circle().fill(col).frame(width: 7, height: 7); Text(st.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1) }
                Text(st.detail).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                if let p = st.progress { ProgressView(value: p).tint(col) }
            }
            Spacer(minLength: 0)
            LiveTrailing(st: st, big: true)
        }
        .padding(16)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

@main
struct OrvexWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        VisitsWidget()
        GateWidget()
        OrvexLive()
    }
}
