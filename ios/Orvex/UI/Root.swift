import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var guardian = Guardian.shared
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            prefs.theme.bg.ignoresSafeArea()
            switch session.phase {
            case .loading: Splash()
            case .login: LoginView()
            case .ready: MainTabs()
            case .killed(let m): KilledView(message: m)
            case .offline(let m): OfflineView(message: m)
            }
            if guardian.locked && session.phase == .ready { LockView().transition(.opacity).zIndex(5) }
            ToastLayer().zIndex(10)
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .animation(.easeInOut(duration: 0.2), value: guardian.locked)
        .onAppear { prefs.systemDark = scheme == .dark }
        .onChange(of: scheme) { _, s in prefs.systemDark = s == .dark }
        .sheet(item: Binding(get: { session.pendingUpdate.map { UpdateItem(j: $0) } }, set: { if $0 == nil { session.pendingUpdate = nil } })) { it in
            UpdateSheet(update: it.j).presentationDetents([.large]).interactiveDismissDisabled(it.j["mandatory"].isTrue)
        }
        .sheet(isPresented: $guardian.confirmAsk, onDismiss: { if guardian.confirmAsk == false { } }) {
            ConfirmSheet().presentationDetents([.medium])
        }
    }
}
struct UpdateItem: Identifiable { let j: JSON; var id: Int { j["build"].int ?? 0 } }

struct Splash: View {
    var body: some View {
        VStack(spacing: 18) {
            OrvexSymbol(size: 72)
            ProgressView()
        }
    }
}

// MARK: - التبويبات
struct MainTabs: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var router = Router.shared
    @ObservedObject var store = ConfigStore.shared

    struct TabDef { let id: String; let title: String; let icon: String; let ok: Bool }
    var tabs: [TabDef] {
        let s = session
        let all: [String: TabDef] = [
            "home": TabDef(id: "home", title: "الرئيسية", icon: "square.grid.2x2.fill", ok: true),
            "site": TabDef(id: "site", title: "الموقع", icon: "globe", ok: s.canAny(["gate", "gate.state", "gate.schedule", "mode.maintenance", "mode.offline", "plans", "content", "texts", "mood", "train", "look", "design", "themes", "advanced", "geo"])),
            "stats": TabDef(id: "stats", title: "الزوار", icon: "chart.bar.xaxis", ok: s.canAny(["stats", "live", "speed"])),
            "telegram": TabDef(id: "telegram", title: "التيليجرام", icon: "paperplane.fill", ok: s.canAny(["waitlist.view", "notify", "waitlist.cast"])),
            "more": TabDef(id: "more", title: "المزيد", icon: "ellipsis.circle.fill", ok: true),
        ]
        return prefs.d.tabs.compactMap { all[$0] }.filter(\.ok)
    }

    var body: some View {
        TabView(selection: $router.tab) {
            ForEach(tabs, id: \.id) { t in
                Tab(t.title, systemImage: t.icon, value: t.id) {
                    tabContent(t.id)
                }
                .badge(t.id == "more" ? session.unread : 0)
            }
            Tab(value: "search", role: .search) {
                NavigationStack { SpotlightView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .modifier(TabMinimize())
        .safeAreaInset(edge: .bottom, spacing: 0) { SaveBar().animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.dirtyCount) }
        .task { await store.load() }
    }

    @ViewBuilder func tabContent(_ id: String) -> some View {
        switch id {
        case "home": NavigationStack(path: $router.homePath) { HomeView().withDestinations() }
        case "site": NavigationStack(path: $router.sitePath) { SiteView().withDestinations() }
        case "stats": NavigationStack(path: $router.statsPath) { StatsView().withDestinations() }
        case "telegram": NavigationStack(path: $router.tgPath) { TelegramView().withDestinations() }
        default: NavigationStack(path: $router.morePath) { MoreView().withDestinations() }
        }
    }
}
struct TabMinimize: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.tabBarMinimizeBehavior(.onScrollDown) } else { content }
    }
}

// MARK: - القفل والإيقاف والتحديث
struct LockView: View {
    @ObservedObject var guardian = Guardian.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        ZStack {
            prefs.theme.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                OrvexSymbol(size: 64)
                Text("أورفيكس مقفول").font(.ox(22, .bold)).foregroundStyle(prefs.theme.ink)
                Button { Task { await guardian.unlock() } } label: { Label("افتح بـ\(guardian.biometryName)", systemImage: guardian.biometryIcon) }
                    .buttonStyle(.oxProminent)
            }
        }.task { await guardian.unlock() }
    }
}
struct KilledView: View {
    var message: String
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        VStack(spacing: 18) {
            OrvexSymbol(size: 60)
            Image(systemName: "pause.circle.fill").font(.system(size: 42)).foregroundStyle(prefs.theme.warn)
            Text("التطبيق موقوف مؤقتًا").font(.ox(22, .bold)).foregroundStyle(prefs.theme.ink)
            Text(message).font(.ox(15)).foregroundStyle(prefs.theme.mute).multilineTextAlignment(.center).padding(.horizontal, 30)
            AsyncButton(action: { await session.boot() }) { Label("جرّب مرة ثانية", systemImage: "arrow.clockwise") }.buttonStyle(.oxGlass)
            Button("تسجيل الخروج") { Task { await session.logout() } }.font(.ox(14)).foregroundStyle(prefs.theme.mute)
        }
    }
}
struct OfflineView: View {
    var message: String
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 44)).foregroundStyle(prefs.theme.mute)
            Text("ما كدرت أوصل للسيرفر").font(.ox(20, .bold)).foregroundStyle(prefs.theme.ink)
            Text(message).font(.ox(14)).foregroundStyle(prefs.theme.mute).multilineTextAlignment(.center).padding(.horizontal, 30)
            AsyncButton(action: { await session.boot() }) { Label("جرّب مرة ثانية", systemImage: "arrow.clockwise") }.buttonStyle(.oxProminent)
            Button("تسجيل الخروج") { session.signOutLocal() }.font(.ox(14)).foregroundStyle(prefs.theme.mute)
        }
    }
}

struct UpdateSheet: View {
    var update: JSON
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(t.surface2).frame(width: 104, height: 104)
                    OrvexSymbol(size: 58)
                }.padding(.top, 30)
                VStack(spacing: 6) {
                    Pill(text: "تحديث جديد", tone: "ok", icon: "sparkles")
                    Text("أورفيكس \(update["version"].str)").font(.ox(28, .bold)).foregroundStyle(t.ink)
                    Text("بناء \(Fmt.n(update["build"])) · \(Fmt.bytes(update["size"].double ?? 0)) · \(Fmt.ago(update["at"].date))").font(.ox(13)).foregroundStyle(t.mute)
                    Text("نسختك الحالية \(Bundle.main.version) (\(Bundle.main.build))").font(.ox(12)).foregroundStyle(t.mute)
                }
                if !update["notes"].arr.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("الجديد بهذا الإصدار").font(.ox(16, .semibold)).foregroundStyle(t.ink)
                        ForEach(Array(update["notes"].arr.enumerated()), id: \.offset) { _, n in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(t.ok).font(.system(size: 15))
                                Text(n.str).font(.ox(15)).foregroundStyle(t.ink2).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(18).background(t.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                VStack(spacing: 10) {
                    Button { if let u = URL(string: update["url"].str) { openURL(u) } } label: { Label("تحميل التحديث", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.oxProminent).accessibilityIdentifier("downloadUpdate")
                    Text("ينفتح سفاري ويتحمّل الملف. بعدها وقّعه بتطبيق التوقيع مالتك وثبّته.").font(.ox(12)).foregroundStyle(t.mute).multilineTextAlignment(.center)
                    if !update["mandatory"].isTrue { Button("بعدين") { dismiss() }.font(.ox(15)).foregroundStyle(t.mute).padding(.top, 4) }
                }
            }.padding(.horizontal, 22).padding(.bottom, 30)
        }.background(t.bg.ignoresSafeArea())
    }
}

struct ConfirmSheet: View {
    @ObservedObject var guardian = Guardian.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var code = ""
    @FocusState private var focus: Bool
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill").font(.system(size: 40)).foregroundStyle(prefs.theme.warn).padding(.top, 26)
            Text("تأكيد إجراء حساس").font(.ox(20, .bold)).foregroundStyle(prefs.theme.ink)
            Text(guardian.confirmHasPin ? "اكتب رمزك السري" : "اكتب كلمة السر مالتك").font(.ox(14)).foregroundStyle(prefs.theme.mute)
            SecureField(guardian.confirmHasPin ? "الرمز السري" : "كلمة السر", text: $code)
                .keyboardType(guardian.confirmHasPin ? .numberPad : .default)
                .font(.ox(18)).multilineTextAlignment(.center).padding(14)
                .background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .focused($focus).padding(.horizontal, 30)
            HStack {
                Button("إلغاء") { guardian.finishConfirm(nil) }.buttonStyle(.oxGlass)
                Button("تأكيد") { guardian.finishConfirm(code) }.buttonStyle(.oxProminent).disabled(code.isEmpty)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity).background(prefs.theme.bg.ignoresSafeArea())
        .onAppear { code = ""; focus = true }
        .onDisappear { guardian.finishConfirm(nil) }
    }
}
