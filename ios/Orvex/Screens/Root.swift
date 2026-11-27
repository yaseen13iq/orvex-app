import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var confirmer = Confirmer.shared
    var body: some View {
        ZStack(alignment: .top) {
            switch session.phase {
            case .loading: SplashView()
            case .login: LoginView()
            case .ready: MainTabs()
            case .killed(let m): StopView(icon: "pause.circle", title: "التطبيق متوقف مؤقتًا", message: m, retry: true)
            case .offline(let m): StopView(icon: "wifi.exclamationmark", title: "تعذّر الاتصال بالخادم", message: m, retry: true)
            }
            ToastLayer()
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .sheet(isPresented: $confirmer.asking, onDismiss: { if confirmer.asking == false { confirmer.finish(nil) } }) { ConfirmSheet() }
        .sheet(item: Binding(get: { session.pendingUpdate.map { UpdateItem(u: $0) } }, set: { if $0 == nil { session.pendingUpdate = nil } })) { it in
            UpdateSheet(update: it.u).interactiveDismissDisabled(it.u["mandatory"].isTrue)
        }
        .alert(session.alert?["title"].str ?? "", isPresented: Binding(get: { session.alert != nil && session.pendingUpdate == nil && !confirmer.asking && session.phase == .ready }, set: { if !$0 { session.alert = nil } })) {
            Button("عرض الإشعارات") { session.alert = nil; Router.shared.open("inbox") }
            Button("حسنًا", role: .cancel) { session.alert = nil }
        } message: { Text(session.alert?["body"].str ?? "") }
    }
}
struct UpdateItem: Identifiable { let id = UUID(); let u: JSON }

// MARK: - التبويبات الأربعة
struct MainTabs: View {
    @EnvironmentObject var session: Session
    @ObservedObject var router = Router.shared
    var body: some View {
        TabView(selection: $router.tab) {
            Tab("الرئيسية", systemImage: "house", value: "home") {
                NavigationStack(path: $router.homePath) { HomeView().withDestinations() }.saveBar()
            }
            Tab("الموقع", systemImage: "globe", value: "site") {
                NavigationStack(path: $router.sitePath) { SiteView().withDestinations() }.saveBar()
            }
            Tab("الإحصاءات", systemImage: "chart.bar", value: "stats") {
                NavigationStack(path: $router.statsPath) { StatsView().withDestinations() }.saveBar()
            }
            Tab("الإدارة", systemImage: "person.crop.circle", value: "admin") {
                NavigationStack(path: $router.adminPath) { AdminView().withDestinations() }.saveBar()
            }
            .badge(session.unread)
        }
        .onChange(of: router.tab) { _, _ in Haptics.tap() }
    }
}

extension View {
    func saveBar() -> some View { safeAreaInset(edge: .bottom, spacing: 0) { SaveBar() } }
}

// MARK: - الوجهات
struct UserRoute: Hashable { var id: String }
struct VersionRoute: Hashable { var id: Int }
struct CastRoute: Hashable { var id: String }

struct DestinationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: String.self) { ScreenFor(id: $0) }
            .navigationDestination(for: AnyHashableRoute.self) { r in
                switch r {
                case .form(let id, let base): FormPage(def: Defs.form(id), base: base)
                case .list(let id, let path): ListPage(def: Defs.list(id), path: path)
                case .screen(let s): ScreenFor(id: s)
                }
            }
            .navigationDestination(for: UserRoute.self) { UserEditView(id: $0.id) }
            .navigationDestination(for: VersionRoute.self) { VersionDetailView(id: $0.id) }
            .navigationDestination(for: CastRoute.self) { CastDetailView(id: $0.id) }
    }
}
extension View { func withDestinations() -> some View { modifier(DestinationsModifier()) } }

struct ScreenFor: View {
    let id: String
    var body: some View {
        switch id {
        // الموقع
        case "gate": GateView()
        case "schedule": ScheduleView()
        case "plans": ListPage(def: Defs.list("plans"), path: P("plans"))
        case "pricing": FormPage(def: Defs.form("pricing"), base: [])
        case "sections": HomeSectionsView()
        case "faq": ListPage(def: Defs.list("faq"), path: P("faq"))
        case "pages": PagesView()
        case "links": FormPage(def: Defs.form("links"), base: [])
        case "seo": FormPage(def: Defs.form("seo"), base: [])
        case "look": FormPage(def: Defs.form("look"), base: [])
        case "mood": FormPage(def: Defs.form("mood"), base: [])
        case "texts": TextsView()
        case "mode": ModeView()
        case "geo": GeoView()
        // الإحصاءات
        case "live": LiveView()
        case "speed": SpeedView()
        // الإدارة
        case "waitlist": WaitlistView()
        case "cast": CastComposeView()
        case "casts": CastsView()
        case "bot": FormPage(def: Defs.form("bot"), base: P("notify"))
        case "users": UsersView()
        case "history": HistoryView()
        case "log": ActivityLogView()
        case "files": FilesView()
        case "app-updates": AppUpdatesView()
        case "app-control": AppControlView()
        case "system": SystemView()
        case "inbox": InboxView()
        case "notify-send": SendNoteView()
        case "settings": SettingsView()
        case "about": AboutView()
        case "search": SearchView()
        default: EmptyState(icon: "questionmark.circle", title: "الصفحة غير موجودة")
        }
    }
}

// MARK: - الشاشات العامة
struct SplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            OrvexSymbol(size: 64)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(C.bg.ignoresSafeArea())
    }
}

struct StopView: View {
    var icon: String
    var title: String
    var message: String
    var retry = false
    @EnvironmentObject var session: Session
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon).font(.system(size: 46, weight: .light)).foregroundStyle(C.mute)
            Text(title).font(.ox(21, .bold)).foregroundStyle(C.ink)
            Text(message).font(.ox(15)).foregroundStyle(C.mute).multilineTextAlignment(.center).lineSpacing(3).padding(.horizontal, 30)
            if retry {
                PrimaryButton(title: "إعادة المحاولة", icon: "arrow.clockwise") { session.phase = .loading; await session.start() }.frame(maxWidth: 300).padding(.top, 8)
                Button("تسجيل الخروج") { session.signOutLocal() }.font(.ox(14)).foregroundStyle(C.mute)
            }
            Spacer()
            Text("تصميم وتطوير ياسين محمد").font(.ox(12)).foregroundStyle(C.mute)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(C.bg.ignoresSafeArea())
    }
}

/// تأكيد الإجراءات الحسّاسة
struct ConfirmSheet: View {
    @ObservedObject var c = Confirmer.shared
    @State private var code = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield").font(.system(size: 38, weight: .light)).foregroundStyle(C.ink).padding(.top, 26)
            Text("تأكيد إجراء حسّاس").font(.ox(20, .bold))
            Text("أدخل كلمة المرور (أو الرمز السري إن كنت قد حددته) لتأكيد هذا الإجراء.").font(.ox(14)).foregroundStyle(C.mute).multilineTextAlignment(.center).padding(.horizontal, 24)
            SecureField("كلمة المرور", text: $code).focused($focused).font(.ox(16))
                .padding(14).background(C.fill, in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 20)
                .submitLabel(.done).onSubmit { if !code.isEmpty { c.finish(code) } }
                .accessibilityIdentifier("confirmCode")
            PrimaryButton(title: "تأكيد", disabled: code.isEmpty) { c.finish(code) }
            Button("إلغاء") { c.finish(nil) }.font(.ox(15)).foregroundStyle(C.mute)
            Spacer()
        }
        .presentationDetents([.medium])
        .presentationBackground(C.bg)
        .onAppear { code = ""; focused = true }
    }
}

/// بطاقة التحديث الجديد
struct UpdateSheet: View {
    let update: JSON
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(C.line).frame(width: 40, height: 5).padding(.top, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x0B0C0E)).frame(width: 64, height: 64)
                            OrvexSymbol(size: 36, color: .white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("تحديث جديد متاح").font(.ox(21, .bold))
                            Text("الإصدار \(update["version"].str) · بناء \(Fmt.n(update["build"]))").font(.ox(13.5)).foregroundStyle(C.mute)
                        }
                    }
                    if update["mandatory"].isTrue { Note(text: "هذا التحديث إلزامي، ويجب تثبيته لمتابعة استخدام التطبيق.", tone: "warn", icon: "exclamationmark.triangle.fill").padding(.horizontal, -16) }
                    let notes = update["notes"].str.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    if !notes.isEmpty {
                        Text("ما الجديد").font(.ox(14, .semibold)).foregroundStyle(C.mute)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(notes.indices, id: \.self) { i in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(C.ok).padding(.top, 2)
                                    Text(notes[i].trimmingCharacters(in: CharacterSet(charactersIn: "-•· "))).font(.ox(15)).lineSpacing(2)
                                }
                            }
                        }
                    }
                    Text("نسختك الحالية \(Bundle.main.version) · بناء \(Fmt.n(Bundle.main.build))").font(.ox(12.5)).foregroundStyle(C.mute)
                }
                .padding(22)
            }
            VStack(spacing: 10) {
                PrimaryButton(title: "تنزيل التحديث", icon: "arrow.down.circle.fill") {
                    if let u = URL(string: update["url"].str), !update["url"].str.isEmpty { await UIApplication.shared.open(u) }
                }
                .accessibilityIdentifier("downloadUpdate")
                if !update["mandatory"].isTrue {
                    Button("لاحقًا") { dismiss() }.font(.ox(15)).foregroundStyle(C.mute).frame(height: 40).accessibilityIdentifier("laterBtn")
                }
                Text("يُنزَّل الملف عبر Safari، ثم ثبّته بتطبيق التوقيع كالمعتاد.").font(.ox(12)).foregroundStyle(C.mute).padding(.bottom, 8)
            }
        }
        .background(C.bg.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
