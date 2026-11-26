import SwiftUI
import WidgetKit
import UniformTypeIdentifiers
import ActivityKit

// MARK: - تحديثات التطبيق
struct AppUpdatesView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    @StateObject private var files = Remote("/files?kind=app")
    @StateObject private var up = Uploader()
    @State private var fileId = ""
    @State private var version = ""
    @State private var build = ""
    @State private var notes = ""
    @State private var mandatory = false
    @State private var importing = false
    @State private var preview = false

    var current: JSON { store.v(P("app", "update")) }
    var body: some View {
        let t = prefs.theme
        Form {
            Section {
                InfoRow(title: "نسختك المثبّتة", value: "\(Bundle.main.version) (\(Bundle.main.build))", icon: "iphone")
                if current.isObject && (current["build"].int ?? 0) > 0 {
                    InfoRow(title: "آخر تحديث منشور", value: "\(current["version"].str) (\(current["build"].str))", icon: "arrow.down.app.fill", tone: "ok")
                    InfoRow(title: "نشره", value: "\(current["by"].str) · \(Fmt.ago(current["at"].date))")
                    if current["mandatory"].isTrue { InfoRow(title: "إجباري", value: "إي", tone: "warn") }
                    Button { preview = true } label: { Label("شوف بطاقة التحديث مثل ما يشوفها المشرف", systemImage: "eye") }
                    AsyncButton(role: .destructive, action: { await clear() }) { Label("اسحب التحديث", systemImage: "xmark.circle") }
                } else {
                    Text("ماكو تحديث منشور هسه").font(.ox(14)).foregroundStyle(t.mute)
                }
            } header: { Text("الحالة") }

            Section {
                Button { importing = true } label: { Label("ارفع ملف IPA جديد", systemImage: "square.and.arrow.up.fill") }.accessibilityIdentifier("pickIPA")
                UploadJobsView(up: up)
                let apps = files.data["items"].arr.filter { $0["name"].str.lowercased().hasSuffix(".ipa") }
                if !apps.isEmpty {
                    Picker("الملف", selection: $fileId) {
                        Text("اختر…").tag("")
                        ForEach(Array(apps.enumerated()), id: \.offset) { _, f in Text("\(f["name"].str) · \(Fmt.bytes(f["size"].double ?? 0))").tag(f["id"].str) }
                    }.font(.ox(14.5))
                }
            } header: { Text("1. ملف التحديث") } footer: { Text("حمّل الـIPA من GitHub، ارفعه هنا. ينحفظ بمخزن الملفات وينطي رابط تحميل مباشر.").font(.ox(12)) }

            Section {
                TextField("رقم الإصدار مثل 1.1.0", text: $version).keyboardType(.decimalPad).environment(\.layoutDirection, .leftToRight).accessibilityIdentifier("updVersion")
                TextField("رقم البناء مثل 2", text: $build).keyboardType(.numberPad).environment(\.layoutDirection, .leftToRight).accessibilityIdentifier("updBuild")
                TextField("الجديد بهذا الإصدار — كل ميزة بسطر", text: $notes, axis: .vertical).font(.ox(15)).lineLimit(4...12)
                Toggle(isOn: $mandatory) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("تحديث إجباري").font(.ox(15))
                        Text("المشرف ما يكدر يسد البطاقة لحد ما يحدّث").font(.ox(12)).foregroundStyle(t.mute)
                    }
                }
            } header: { Text("2. التفاصيل") } footer: { Text("رقم البناء لازم يكون أكبر من رقم البناء المثبّت حتى تطلع البطاقة.").font(.ox(12)) }

            Section {
                AsyncButton(action: { await publish() }) { Label("انشر التحديث لكل المشرفين", systemImage: "paperplane.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.oxProminent).listRowBackground(Color.clear)
                    .disabled(fileId.isEmpty || version.isEmpty || (Int(build) ?? 0) < 1)
            }
        }
        .formStyle(.grouped)
        .oxScreen("تحديثات التطبيق", page: "app-updates")
        .task {
            up.onDone = { f in Task { await files.load(); fileId = f["id"].str } }
            await files.load()
            if version.isEmpty { let parts = Bundle.main.version.split(separator: ".").compactMap { Int($0) }; if parts.count >= 2 { version = "\(parts[0]).\(parts[1] + 1).0" } }
            if build.isEmpty { build = String(max(Bundle.main.build, current["build"].int ?? 0) + 1) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { res in
            if case .success(let u) = res { Task { await up.upload(url: u) } }
        }
        .sheet(isPresented: $preview) {
            UpdateSheet(update: current)
        }
    }
    func publish() async {
        do {
            let r = try await API.shared.post("/app/update", ["fileId": .string(fileId), "version": .string(version), "build": .number(Double(Int(build) ?? 0)), "notes": .string(notes), "mandatory": .bool(mandatory)])
            Toasts.shared.show("انشر التحديث \(r["update"]["version"].str) ✓ وانرسل إشعار للكل")
            await store.load(force: true)
            await session.boot()
        } catch { Toasts.shared.error(error) }
    }
    func clear() async {
        do { try await API.shared.post("/app/update/clear"); Toasts.shared.show("انسحب التحديث"); await store.load(force: true) } catch { Toasts.shared.error(error) }
    }
}

// MARK: - التحكم بالتطبيق
struct AppControlView: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var store = ConfigStore.shared
    @State private var askKill = false
    var app: JSON { store.v(P("app")) }
    func put(_ k: String, _ v: JSON) {
        var a = app.isObject ? app : ["enabled": true, "message": "", "display": [:]]
        a[k] = v
        store.set(P("app"), a)
    }
    func putDisplay(_ k: String, _ v: String) {
        var d = app["display"]; if !d.isObject { d = [:] }
        d[k] = .string(v); put("display", d)
    }
    var body: some View {
        let t = prefs.theme
        let enabled = app["enabled"].bool ?? true
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: enabled ? "power.circle.fill" : "pause.circle.fill").font(.system(size: 36)).foregroundStyle(enabled ? t.ok : t.bad)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(enabled ? "التطبيق شغّال للمشرفين" : "التطبيق موقوف للمشرفين").font(.ox(16, .semibold))
                        Text("انت (المسؤول الرئيسي) ما تتأثر أبدًا").font(.ox(12.5)).foregroundStyle(t.mute)
                    }
                }.padding(.vertical, 4)
                Button(role: enabled ? .destructive : nil) { if enabled { askKill = true } else { put("enabled", true) } } label: {
                    Label(enabled ? "أوقف التطبيق لكل المشرفين" : "شغّل التطبيق", systemImage: enabled ? "stop.circle" : "play.circle").font(.ox(15, .semibold))
                }.accessibilityIdentifier("killSwitch")
                TextField("الرسالة اللي يشوفونها وقت الإيقاف", text: Binding(get: { app["message"].text }, set: { put("message", .string($0)) }), axis: .vertical).font(.ox(15))
            } header: { Text("زر الإيقاف الكامل") } footer: { Text("لما توقفه، أي مشرف يفتح التطبيق يشوف رسالة الإيقاف وما يكدر يسوي شي. اللوحة بالمتصفح تبقى حسب صلاحياته.").font(.ox(12)) }

            Section {
                Picker("الثيم", selection: Binding(get: { app["display"]["theme"].string ?? "auto" }, set: { putDisplay("theme", $0) })) {
                    Text("تلقائي").tag("auto")
                    ForEach(AppTheme.all) { th in Text(th.name).tag(th.id) }
                }
                Picker("الوضع", selection: Binding(get: { app["display"]["scheme"].string ?? "system" }, set: { putDisplay("scheme", $0) })) {
                    Text("حسب الجهاز").tag("system"); Text("فاتح").tag("light"); Text("داكن").tag("dark")
                }
                Picker("الزجاج", selection: Binding(get: { app["display"]["glass"].string ?? "full" }, set: { putDisplay("glass", $0) })) {
                    Text("كامل").tag("full"); Text("خفيف").tag("soft"); Text("بدون").tag("off")
                }
                Picker("التباعد", selection: Binding(get: { app["display"]["density"].string ?? "comfortable" }, set: { putDisplay("density", $0) })) {
                    Text("مريح").tag("comfortable"); Text("مضغوط").tag("compact")
                }
            } header: { Text("الشكل الافتراضي للمشرفين") } footer: { Text("يطبق على المشرفين اللي ما عندهم صلاحية «تخصيص شكل التطبيق لنفسه». اللي عنده الصلاحية يختار بنفسه.").font(.ox(12)) }
        }
        .formStyle(.grouped)
        .oxScreen("التحكم بالتطبيق", page: "app-control")
        .confirmationDialog("توقف التطبيق لكل المشرفين؟", isPresented: $askKill, titleVisibility: .visible) {
            Button("أوقفه", role: .destructive) { put("enabled", false) }
        } message: { Text("بعدها اضغط «احفظ». تكدر ترجعه بأي وقت.") }
    }
}

// MARK: - تخصيص شاشة الآيفون (الويدجت والجزيرة)
struct WidgetsCustomizeView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @State private var w = WidgetPrefs.load()
    @State private var sharing = Vault.sharingWorks
    @State private var size = "small"
    var body: some View {
        let t = prefs.theme
        Form {
            Section {
                WidgetMock(prefs: w, size: size, status: session.status)
                    .frame(maxWidth: .infinity).padding(.vertical, 10).listRowBackground(Color.clear)
                Picker("", selection: $size) { Text("صغير").tag("small"); Text("متوسط").tag("medium"); Text("قفل الشاشة").tag("lock") }.pickerStyle(.segmented)
            } header: { Text("المعاينة") }
            if !sharing {
                Section {
                    Label("الشهادة اللي وقّعت بيها التطبيق ما تسمح بمشاركة البيانات مع الويدجت. الويدجت راح يعرض «افتح التطبيق» بدل الأرقام.", systemImage: "exclamationmark.triangle.fill").font(.ox(13)).foregroundStyle(t.warn)
                }
            }
            Section {
                Picker("المظهر", selection: $w.theme) { Text("حسب الجهاز").tag("auto"); Text("فاتح").tag("light"); Text("داكن").tag("dark") }
                Toggle("حالة الموقع والاشتراكات", isOn: $w.showGate)
                if session.canAny(["stats", "live"]) {
                    Toggle("المتصفحين هسه", isOn: $w.showLive)
                    Toggle("زيارات اليوم", isOn: $w.showVisits)
                }
                if session.can("waitlist.view") { Toggle("عدد المنتظرين", isOn: $w.showWaitlist) }
                Toggle("رقم الإصدار", isOn: $w.showVersion)
                Toggle(isOn: $w.hideSensitive) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("اخفِ الأرقام الحساسة").font(.ox(15))
                        Text("تنعرض نقاط بدل الأرقام على قفل الشاشة").font(.ox(12)).foregroundStyle(t.mute)
                    }
                }
            } header: { Text("الويدجت") } footer: { Text("أضف الويدجت: اضغط مطوّل على الشاشة الرئيسية ← زر + ← ابحث عن «أورفيكس».").font(.ox(12)) }

            Section {
                Toggle(isOn: $w.islandEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("الجزيرة التفاعلية").font(.ox(16, .semibold))
                        Text("مطفية افتراضيًا").font(.ox(12)).foregroundStyle(t.mute)
                    }
                }.accessibilityIdentifier("islandToggle")
                if w.islandEnabled {
                    Toggle("حالة الموقع", isOn: $w.islandStatus)
                    Toggle("مشاكل الموقع", isOn: $w.islandProblems)
                    Toggle("مؤقت الصيانة والإيقاف", isOn: $w.islandMaintenance)
                    Toggle("موعد فتح وإغلاق الاشتراكات", isOn: $w.islandSchedule)
                    Toggle("تقدّم الإرسال الجماعي", isOn: $w.islandCast)
                    Toggle("التنبيهات المهمة", isOn: $w.islandAlerts)
                    if !LiveCenter.shared.available { Label("الأنشطة المباشرة مطفية من إعدادات الآيفون ← أورفيكس", systemImage: "exclamationmark.circle").font(.ox(12.5)).foregroundStyle(t.warn) }
                }
            } header: { Text("الجزيرة وقفل الشاشة") } footer: { Text("العدّادات (مثل وقت الصيانة) تمشي لحالها. باقي المعلومات تتحدث لما تفتح التطبيق أو كل فترة بالخلفية.").font(.ox(12)) }
        }
        .formStyle(.grouped)
        .oxScreen("تخصيص شاشة الآيفون", page: "widgets")
        .onChange(of: w) { _, v in
            v.save()
            WidgetCenter.shared.reloadAllTimelines()
            LiveCenter.shared.sync(with: session.status)
        }
    }
}

/// معاينة شكل الويدجت داخل التطبيق
struct WidgetMock: View {
    let prefs: WidgetPrefs
    let size: String
    let status: JSON
    @Environment(\.colorScheme) var scheme
    var dark: Bool { prefs.theme == "dark" || (prefs.theme == "auto" && scheme == .dark) }
    var body: some View {
        let bg = dark ? Color(hex: 0x0B0C0E) : Color(hex: 0xEEF0F3), ink = dark ? Color.white : Color(hex: 0x0B0C0E), mute = dark ? Color(hex: 0x8A919C) : Color(hex: 0x5F6772)
        let h = status["health"].str
        let dot: Color = h == "ok" ? Color(hex: 0x3DD68C) : h == "maintenance" || h == "warn" ? Color(hex: 0xF0B44C) : Color(hex: 0xF0626A)
        func num(_ v: JSON) -> String { prefs.hideSensitive ? "••" : Fmt.n(v) }
        return Group {
            if size == "lock" {
                HStack(spacing: 8) {
                    Image("OrvexSymbol").resizable().scaledToFit().frame(width: 18)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(status["gate"]["label"].text.isEmpty ? "الاشتراكات" : status["gate"]["label"].text).font(.system(size: 13, weight: .semibold))
                        Text("\(num(status["live"])) هسه · \(num(status["today"]["views"])) اليوم").font(.system(size: 11))
                    }
                }
                .foregroundStyle(.white).padding(10).frame(width: 170, alignment: .leading)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Image("OrvexSymbol").resizable().renderingMode(.template).scaledToFit().frame(width: 18).foregroundStyle(ink); Spacer(); Circle().fill(dot).frame(width: 9, height: 9) }
                    Spacer(minLength: 0)
                    if prefs.showGate { Text(status["gate"]["label"].text.isEmpty ? "—" : status["gate"]["label"].text).font(.system(size: 15, weight: .bold)).foregroundStyle(ink) }
                    HStack(spacing: 14) {
                        if prefs.showLive { stat("هسه", num(status["live"]), ink, mute) }
                        if prefs.showVisits { stat("اليوم", num(status["today"]["views"]), ink, mute) }
                        if size == "medium" && prefs.showWaitlist { stat("المنتظرين", num(status["waitlist"]), ink, mute) }
                        if size == "medium" && prefs.showVersion { stat("الإصدار", status["version"].str, ink, mute) }
                    }
                }
                .padding(14)
                .frame(width: size == "medium" ? 330 : 158, height: 158)
                .background(bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            }
        }
    }
    func stat(_ k: String, _ v: String, _ ink: Color, _ mute: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(v).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(ink)
            Text(k).font(.system(size: 10)).foregroundStyle(mute)
        }
    }
}

// MARK: - الإعدادات والمظهر
struct SettingsView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var guardian = Guardian.shared
    @State private var icon = UIApplication.shared.alternateIconName ?? "AppIcon"
    @State private var askReset = false
    static let icons: [(String, String)] = [("AppIcon", "التوقيع"), ("IconObsidian", "أسود"), ("IconClassic", "كلاسيك"), ("IconWhite", "أبيض"), ("IconMist", "ضباب"), ("IconSilver", "فضي"), ("IconSteel", "فولاذ"), ("IconOutline", "خطوط"), ("IconOutlineLight", "خطوط فاتحة"), ("IconBlueprint", "المخطط")]
    let tabNames: [String: (String, String)] = ["home": ("الرئيسية", "square.grid.2x2.fill"), "site": ("الموقع", "globe"), "stats": ("الزوار", "chart.bar.xaxis"), "telegram": ("التيليجرام", "paperplane.fill"), "more": ("المزيد", "ellipsis.circle.fill")]
    let cardNames: [String: String] = ["status": "حالة الموقع", "kpis": "الأرقام", "gate": "الاشتراكات السريعة", "actions": "الاختصارات", "live": "المتصفحين", "recent": "آخر التعديلات"]

    var body: some View {
        let t = prefs.theme
        Form {
            if prefs.locked {
                Section { Label("المسؤول الرئيسي ثبّت شكل التطبيق. تكدر تغيّر الأيقونة والقفل بس.", systemImage: "lock.fill").font(.ox(13.5)).foregroundStyle(t.mute) }
            } else {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                        themeTile(id: "auto", name: "تلقائي", a: AppTheme.obsidian, b: AppTheme.mist)
                        ForEach(AppTheme.all) { th in themeTile(id: th.id, name: th.name, a: th, b: th) }
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    if prefs.d.theme == "auto" {
                        Picker("الوضع", selection: $prefs.d.scheme) { Text("حسب الجهاز").tag("system"); Text("فاتح").tag("light"); Text("داكن").tag("dark") }.pickerStyle(.segmented)
                        Picker("الثيم الفاتح", selection: $prefs.d.lightTheme) { ForEach(AppTheme.all.filter { !$0.dark }) { Text($0.name).tag($0.id) } }
                        Picker("الثيم الداكن", selection: $prefs.d.darkTheme) { ForEach(AppTheme.all.filter(\.dark)) { Text($0.name).tag($0.id) } }
                    }
                } header: { Text("الثيم") }

                Section {
                    VStack(alignment: .leading) {
                        HStack { Text("حجم الخط").font(.ox(15)); Spacer(); Text("\(Int(prefs.d.textScale * 100))%").font(.num(13)) }
                        Slider(value: $prefs.d.textScale, in: 0.85...1.3, step: 0.05)
                    }
                    Picker("التباعد", selection: $prefs.d.density) { Text("مريح").tag("comfortable"); Text("مضغوط").tag("compact") }
                    Picker("الزجاج (Liquid Glass)", selection: $prefs.d.glass) { Text("كامل").tag("full"); Text("خفيف").tag("soft"); Text("بدون").tag("off") }
                    Toggle("الاهتزاز عند اللمس", isOn: $prefs.d.haptics)
                    Picker("الأرقام", selection: $prefs.d.westernDigits) { Text("123").tag(true); Text("١٢٣").tag(false) }.pickerStyle(.segmented)
                } header: { Text("العرض") }

                Section {
                    Picker("يفتح على", selection: $prefs.d.startTab) { ForEach(prefs.d.tabs, id: \.self) { Text(tabNames[$0]?.0 ?? $0).tag($0) } }
                    ForEach(prefs.d.tabs, id: \.self) { id in Label(tabNames[id]?.0 ?? id, systemImage: tabNames[id]?.1 ?? "circle").font(.ox(15)) }
                        .onMove { prefs.d.tabs.move(fromOffsets: $0, toOffset: $1) }
                } header: { Text("التبويبات — اسحب للترتيب") }

                Section {
                    ForEach(prefs.d.homeCards, id: \.self) { c in
                        Toggle(isOn: Binding(get: { !prefs.d.hiddenHomeCards.contains(c) }, set: { on in if on { prefs.d.hiddenHomeCards.removeAll { $0 == c } } else { prefs.d.hiddenHomeCards.append(c) } })) {
                            Text(cardNames[c] ?? c).font(.ox(15))
                        }
                    }.onMove { prefs.d.homeCards.move(fromOffsets: $0, toOffset: $1) }
                } header: { Text("بطاقات الرئيسية — اسحب للترتيب") }
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 14) {
                    ForEach(SettingsView.icons.indices, id: \.self) { i in
                        let ic = SettingsView.icons[i]
                        Button { setIcon(ic.0) } label: {
                            VStack(spacing: 6) {
                                Image(ic.0 + "Preview").resizable().scaledToFit().frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(icon == ic.0 ? t.accent : t.line, lineWidth: icon == ic.0 ? 2.5 : 1))
                                Text(ic.1).font(.ox(11)).foregroundStyle(icon == ic.0 ? t.ink : t.mute).lineLimit(1)
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("icon-\(ic.0)")
                    }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            } header: { Text("أيقونة التطبيق") }

            Section {
                Picker("قفل التطبيق بـ\(guardian.biometryName)", selection: Binding(get: { prefs.d.lock }, set: { v in Task { if v == "off" || (await guardian.authenticate("فعّل قفل التطبيق")) { prefs.d.lock = v } } })) {
                    Text("مطفي").tag("off"); Text("كل ما أطلع").tag("instant"); Text("بعد دقيقة").tag("1m"); Text("بعد 5 دقائق").tag("5m")
                }.font(.ox(15))
                Toggle("بطاقة التحديث الجديد عند الفتح", isOn: $prefs.d.showUpdateCard).font(.ox(15))
            } header: { Text("الأمان") }

            if !prefs.locked {
                Section {
                    Button(role: .destructive) { askReset = true } label: { Label("رجّع شكل التطبيق للافتراضي", systemImage: "arrow.counterclockwise") }
                }
            }
        }
        .formStyle(.grouped)
        .environment(\.editMode, .constant(.active))
        .oxScreen("الإعدادات والمظهر", page: "settings")
        .confirmationDialog("ترجّع كل إعدادات الشكل للافتراضي؟", isPresented: $askReset, titleVisibility: .visible) {
            Button("رجّعها", role: .destructive) { let l = prefs.d.lock; prefs.reset(); prefs.d.lock = l; setIcon("AppIcon"); Toasts.shared.show("رجع الشكل الافتراضي") }
        }
    }

    func themeTile(id: String, name: String, a: AppTheme, b: AppTheme) -> some View {
        let sel = prefs.d.theme == id
        return Button { withAnimation(.easeInOut(duration: 0.25)) { prefs.d.theme = id }; prefs.tap() } label: {
            VStack(spacing: 6) {
                ZStack {
                    HStack(spacing: 0) { a.bg; b.bg }
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(a.accent).frame(width: 30, height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(a.surface2).frame(height: 14)
                        RoundedRectangle(cornerRadius: 3).fill(b.surface2).frame(height: 14)
                    }.padding(10)
                }
                .frame(height: 70).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(sel ? prefs.theme.accent : prefs.theme.line, lineWidth: sel ? 2.5 : 1))
                Text(name).font(.ox(11.5, sel ? .semibold : .regular)).foregroundStyle(sel ? prefs.theme.ink : prefs.theme.mute)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("theme-\(id)")
    }
    func setIcon(_ name: String) {
        guard UIApplication.shared.supportsAlternateIcons else { Toasts.shared.show("الجهاز ما يدعم تغيير الأيقونة", "warn"); return }
        let n: String? = name == "AppIcon" ? nil : name
        UIApplication.shared.setAlternateIconName(n) { err in
            Task { @MainActor in
                if let e = err { Toasts.shared.show("ما تغيّرت: " + e.localizedDescription, "bad") } else { icon = name }
            }
        }
    }
}
