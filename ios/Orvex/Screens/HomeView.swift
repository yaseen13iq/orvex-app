import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: Session
    @StateObject private var recent = Remote("/history?limit=4")
    @ObservedObject var store = ConfigStore.shared
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var s: JSON { session.status }
    var body: some View {
        Page(title: "الرئيسية", intro: "مرحبًا \(session.firstName)، هذه حالة موقعك الآن.", id: "home") {
            hero
            if !s["problems"].arr.isEmpty {
                Spacer().frame(height: 12)
                VStack(spacing: 8) {
                    ForEach(Array(s["problems"].arr.enumerated()), id: \.offset) { _, p in
                        Note(text: p["t"].str, tone: "warn", icon: "exclamationmark.triangle.fill")
                    }
                }
            }
            if session.canAny(["stats", "live", "waitlist.view"]) {
                SectionTitle("أرقام اليوم")
                KPIGrid {
                    if !s["today"].isNull {
                        Button { Router.shared.open("stats") } label: { KPI(title: "الزيارات", value: Fmt.n(s["today"]["views"]), foot: Fmt.n(s["today"]["uniq"]) + " زائر مختلف") }.buttonStyle(.plain)
                        KPI(title: "المتصفحون الآن", value: Fmt.n(s["live"]), foot: "خلال آخر 5 دقائق")
                    }
                    if !s["waitlist"].isNull { KPI(title: "المنتظرون", value: Fmt.n(s["waitlist"]), foot: "بانتظار فتح الاشتراكات") }
                    if !s["today"].isNull { KPI(title: "نقرات «اشترك»", value: Fmt.n(s["today"]["cta"]), foot: Fmt.n(s["today"]["rem"]) + " نقرة على «ذكّرني»") }
                }
            }
            if session.can("history.view") {
                SectionTitle("آخر التعديلات")
                Card {
                    if recent.data["items"].arr.isEmpty {
                        Text(recent.loaded ? "لا توجد تعديلات بعد." : "جارٍ التحميل…").font(.ox(14)).foregroundStyle(C.mute).padding(16)
                    }
                    ForEach(Array(recent.data["items"].arr.prefix(4).enumerated()), id: \.offset) { _, v in RecentRow(v: v) }
                }
                Button { Router.shared.open("history") } label: {
                    Text("عرض كل التعديلات").font(.ox(14, .medium)).foregroundStyle(C.info).frame(maxWidth: .infinity).padding(.top, 12)
                }.buttonStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: "search") { Image(systemName: "magnifyingglass") }.accessibilityLabel("البحث").accessibilityIdentifier("searchBtn")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: "inbox") {
                    Image(systemName: session.unread > 0 ? "bell.badge" : "bell")
                        .symbolRenderingMode(.palette).foregroundStyle(C.bad, C.ink)
                }.accessibilityLabel("الإشعارات").accessibilityIdentifier("inboxBtn")
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onReceive(timer) { _ in Task { await session.refreshStatus() } }
    }
    func load() async {
        await session.refreshStatus()
        if session.can("history.view") { await recent.load() }
    }

    var healthText: (String, Color) {
        switch s["health"].str {
        case "ok": return ("الموقع يعمل بشكل طبيعي", Color(hex: 0x3DD68C))
        case "maintenance": return ("الموقع في وضع الصيانة", Color(hex: 0xF0B44C))
        case "down": return ("الموقع متوقف عن الزوار", Color(hex: 0xF0626A))
        case "warn": return ("توجد مشكلة تحتاج إلى انتباه", Color(hex: 0xF0B44C))
        default: return ("جارٍ التحقق من حالة الموقع…", Color(hex: 0x8A919C))
        }
    }
    var hero: some View {
        let h = healthText
        let last = recent.data["items"][0]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Circle().fill(h.1).frame(width: 10, height: 10).overlay(Circle().stroke(h.1.opacity(0.25), lineWidth: 6))
                    Text(h.0).font(.ox(17, .semibold)).foregroundStyle(.white)
                }
                Spacer()
                if !s["version"].str.isEmpty { Text(s["version"].str).font(.num(11, .medium)).foregroundStyle(Color(hex: 0x8A919C)) }
            }
            if !last.isNull {
                Text("آخر تعديل \(Fmt.ago(last["at"].date)) بواسطة \(last["uname"].str)").font(.ox(12.5)).foregroundStyle(Color(hex: 0x9AA1AB)).padding(.top, 7)
            }
            HStack(spacing: 10) {
                heroCell("الاشتراكات", Defs.gateStates.first { $0.0 == s["gate"]["state"].str }?.1 ?? "—", "gate")
                if let next = s["schedule"]["next"]["at"].date {
                    heroCell(s["schedule"]["next"]["kind"].str == "close" ? "الإغلاق المجدول" : "الفتح المجدول", Fmt.shortDate(next) + "، " + Fmt.time(next), "schedule")
                } else {
                    heroCell("وضع الموقع", s["mode"].str == "maintenance" ? "صيانة" : s["mode"].str == "offline" ? "متوقف" : "يعمل", "mode")
                }
            }
            .padding(.top, 16)
        }
        .padding(18)
        .background(C.hero, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }
    func heroCell(_ k: String, _ v: String, _ dest: String) -> some View {
        Button { Router.shared.open(dest) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(k).font(.ox(11.5)).foregroundStyle(Color(hex: 0x9AA1AB))
                Text(v).font(.ox(15, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain)
    }
}

/// سطر تعديل مع زر التراجع
struct RecentRow: View {
    let v: JSON
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(v["uname"].str.prefix(1)).uppercased()).font(.ox(13, .semibold)).foregroundStyle(C.ink)
                .frame(width: 32, height: 32).background(C.fill, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(v["what"].str).font(.ox(14.5, .medium)).foregroundStyle(C.ink).lineLimit(2)
                Text("\(v["uname"].str) · \(Fmt.ago(v["at"].date))").font(.ox(12)).foregroundStyle(C.mute)
            }
            Spacer(minLength: 6)
            if session.can("history.undo") && v["kind"].str != "base" {
                Button { Task { await store.undo(v["id"].int ?? 0); await session.refreshStatus() } } label: {
                    Text("تراجع").font(.ox(13, .medium)).foregroundStyle(C.info)
                }.buttonStyle(.plain).padding(.top, 6)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
