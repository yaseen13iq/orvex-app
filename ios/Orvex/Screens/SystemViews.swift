import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - الملفات
struct FilesView: View {
    @EnvironmentObject var session: Session
    @StateObject private var r = Remote("/files")
    @StateObject private var up = Uploader()
    @State private var kind = "all"
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var del: JSON?
    let kinds: [(String, String)] = [("all", "الكل"), ("image", "الصور"), ("video", "الفيديو"), ("audio", "الصوت"), ("doc", "المستندات"), ("app", "التطبيقات"), ("other", "أخرى")]
    var items: [JSON] { r.data["items"].arr.filter { kind == "all" || $0["kind"].str == kind } }
    var body: some View {
        Page(title: "الملفات", intro: "ارفع الصور والملفات، وانسخ رابطها المباشر لاستخدامه في الموقع.", id: "files") {
            if r.error != nil && !r.loaded {
                EmptyState(icon: "externaldrive.badge.xmark", title: "مخزن الملفات غير جاهز", sub: r.error)
            } else if !r.loaded { LoadingView() } else {
                let u = r.data["usage"], total = u["total"].double ?? 0, quota = max(1, u["quota"].double ?? 1)
                Spacer().frame(height: 6)
                Card(padded: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Fmt.bytes(total)).font(.num(24)).foregroundStyle(C.ink)
                            Text("مستخدَم من \(Fmt.bytes(quota))").font(.ox(13)).foregroundStyle(C.mute)
                            Spacer()
                        }
                        ProgressView(value: min(1, total / quota)).tint(total / quota > 0.85 ? C.bad : C.ok)
                        Text("المتبقي: \(Fmt.bytes(u["free"].double ?? max(0, quota - total)))").font(.ox(12.5)).foregroundStyle(C.mute)
                    }
                }
                if session.can("files.upload") {
                    Spacer().frame(height: 12)
                    HStack(spacing: 10) {
                        uploadButton("من الملفات", "folder.badge.plus") { importing = true }
                        uploadButton("من الصور", "photo.badge.plus") { showPhotos = true }
                    }.padding(.horizontal, 16)
                    if !up.jobs.isEmpty {
                        SectionTitle("الرفع")
                        Card { ForEach(up.jobs) { j in UploadRow(j: j) } }
                    }
                }
                SectionTitle("الملفات", trailing: Fmt.n(items.count))
                Chips(options: kinds, selection: $kind).padding(.bottom, 10)
                Card {
                    if items.isEmpty { Text("لا توجد ملفات.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                    ForEach(Array(items.enumerated()), id: \.offset) { _, f in FileRow(f: f) { del = f } }
                }
            }
        }
        .task { up.onDone = { _ in Task { await r.load() } }; await r.load() }
        .refreshable { await r.load() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { for u in urls { Task { await up.upload(url: u) } } }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photos, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
        .onChange(of: photos) { _, list in
            for it in list {
                Task {
                    if let d = try? await it.loadTransferable(type: Data.self) {
                        let ut = it.supportedContentTypes.first ?? .jpeg
                        await up.upload(data: d, name: "صورة-\(Int(Date().timeIntervalSince1970)).\(ut.preferredFilenameExtension ?? "jpg")", type: ut.preferredMIMEType ?? "image/jpeg")
                    }
                }
            }
            photos = []
        }
        .confirmationDialog("حذف «\(del?["name"].str ?? "")»؟", isPresented: Binding(get: { del != nil }, set: { if !$0 { del = nil } }), titleVisibility: .visible) {
            Button("حذف نهائيًا", role: .destructive) { if let f = del { Task { await remove(f) } } }
        } message: { Text("سيتوقف رابط الملف عن العمل.") }
    }
    func uploadButton(_ t: String, _ i: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: i).font(.ox(14.5, .medium)).foregroundStyle(C.ink).frame(maxWidth: .infinity).frame(height: 48).background(C.card, in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("upload-" + t)
    }
    func remove(_ f: JSON) async {
        do { try await API.shared.post("/files/\(f["id"].str)/delete"); Toasts.shared.show("حُذف الملف."); await r.load() } catch { Toasts.shared.error(error) }
    }
}

struct UploadRow: View {
    let j: Uploader.Job
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(j.name).font(.ox(14, .medium)).foregroundStyle(C.ink).lineLimit(1)
                Spacer()
                Text(j.error != nil ? "تعذّر" : j.done ? "اكتمل" : Fmt.percent(j.progress)).font(.ox(13, .semibold)).foregroundStyle(j.error != nil ? C.bad : j.done ? C.ok : C.ink)
            }
            ProgressView(value: j.progress).tint(j.error != nil ? C.bad : C.ok)
            if let e = j.error { Text(e).font(.ox(12)).foregroundStyle(C.bad) }
            if j.done, !j.file["url"].str.isEmpty {
                Button { UIPasteboard.general.string = j.file["url"].str; Toasts.shared.show("نُسخ رابط الملف.") } label: { Label("نسخ الرابط", systemImage: "link").font(.ox(13)) }.buttonStyle(.plain).foregroundStyle(C.info)
            }
        }.padding(14)
    }
}

struct FileRow: View {
    let f: JSON
    var onDelete: () -> Void
    @EnvironmentObject var session: Session
    var icon: String { ["image": "photo", "video": "film", "audio": "waveform", "doc": "doc.text", "app": "app.badge"][f["kind"].str] ?? "doc" }
    var body: some View {
        HStack(spacing: 12) {
            if f["kind"].str == "image", let u = URL(string: f["url"].str) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { C.fill }
                    .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(C.ink2).frame(width: 44, height: 44).background(C.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(f["name"].str).font(.ox(14.5, .medium)).foregroundStyle(C.ink).lineLimit(1).truncationMode(.middle)
                Text("\(Fmt.bytes(f["size"].double ?? 0)) · \(Fmt.ago(f["at"].date))").font(.ox(12)).foregroundStyle(C.mute)
            }
            Spacer(minLength: 0)
            Menu {
                Button { UIPasteboard.general.string = f["url"].str; Toasts.shared.show("نُسخ رابط الملف.") } label: { Label("نسخ الرابط", systemImage: "link") }
                if let u = URL(string: f["url"].str) { ShareLink(item: u) { Label("مشاركة", systemImage: "square.and.arrow.up") } }
                if session.can("files.delete") { Divider(); Button(role: .destructive, action: onDelete) { Label("حذف", systemImage: "trash") } }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)).foregroundStyle(C.mute).frame(width: 36, height: 36) }
        }.padding(.horizontal, 14).padding(.vertical, 9)
    }
}

// MARK: - تحديثات التطبيق
struct AppUpdatesView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var store = ConfigStore.shared
    @StateObject private var files = Remote("/files?kind=app")
    @StateObject private var up = Uploader()
    @State private var fileId = ""
    @State private var version = ""
    @State private var build = ""
    @State private var notes = ""
    @State private var mandatory = false
    @State private var importing = false
    var current: JSON { store.v(P("app", "update")) }
    var apps: [JSON] { files.data["items"].arr.filter { $0["name"].str.lowercased().hasSuffix(".ipa") } }
    var body: some View {
        Page(title: "تحديثات التطبيق", intro: "انشر إصدارًا جديدًا، فتظهر للمشرفين بطاقة التحديث عند فتح التطبيق.", id: "app-updates") {
            SectionTitle("الحالة")
            Card {
                InfoRow(title: "الإصدار المثبّت لديك", value: "\(Bundle.main.version) (بناء \(Fmt.n(Bundle.main.build)))")
                if (current["build"].int ?? 0) > 0 {
                    InfoRow(title: "آخر إصدار منشور", value: "\(current["version"].str) (بناء \(Fmt.n(current["build"])))", tone: "ok")
                    InfoRow(title: "نُشر", value: "\(current["by"].str) · \(Fmt.ago(current["at"].date))")
                    ActionRow(title: "سحب التحديث المنشور", icon: "xmark.circle", tone: "bad") { await clear() }
                } else {
                    InfoRow(title: "آخر إصدار منشور", value: "لا يوجد")
                }
            }
            SectionTitle("١. ملف التحديث")
            Card {
                ActionRow(title: "رفع ملف IPA", icon: "square.and.arrow.up") { importing = true }
                ForEach(up.jobs) { j in UploadRow(j: j) }
                if !apps.isEmpty {
                    ChoiceRow(title: "الملف", options: [("", "اختر ملفًا")] + apps.map { ($0["id"].str, $0["name"].str) }, selection: $fileId)
                }
            }
            SectionFooter("نزّل ملف IPA الجديد، ثم ارفعه هنا. يُحفظ في «الملفات» بالرابط المباشر.")
            SectionTitle("٢. التفاصيل")
            Card {
                TextBlock(title: "رقم الإصدار", placeholder: "2.1.0", text: $version, ltr: true, keyboard: .decimalPad)
                TextBlock(title: "رقم البناء", placeholder: "3", text: $build, ltr: true, keyboard: .numberPad)
                TextBlock(title: "ما الجديد (كل ميزة في سطر)", text: $notes, multiline: true)
                ToggleRow(title: "تحديث إلزامي", sub: "لا يستطيع المشرف إغلاق البطاقة قبل التحديث", isOn: $mandatory)
            }
            SectionFooter("يجب أن يكون رقم البناء أكبر من رقم البناء المثبّت حتى تظهر البطاقة.")
            Spacer().frame(height: 16)
            PrimaryButton(title: "نشر التحديث", icon: "paperplane.fill", disabled: fileId.isEmpty || version.isEmpty || (Int(build) ?? 0) < 1) { await publish() }
        }
        .task {
            up.onDone = { f in Task { await files.load(); fileId = f["id"].str } }
            await files.load()
            if build.isEmpty { build = String(max(Bundle.main.build, current["build"].int ?? 0) + 1) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { res in if case .success(let u) = res { Task { await up.upload(url: u) } } }
    }
    func publish() async {
        do {
            try await API.shared.post("/app/update", ["fileId": .string(fileId), "version": .string(version), "build": .number(Double(Int(build) ?? 0)), "notes": .string(notes), "mandatory": .bool(mandatory)])
            Toasts.shared.show("نُشر التحديث وأُرسل إشعار للفريق.")
            await store.load(force: true); await session.boot()
        } catch { Toasts.shared.error(error) }
    }
    func clear() async {
        do { try await API.shared.post("/app/update/clear"); Toasts.shared.show("سُحب التحديث."); await store.load(force: true) } catch { Toasts.shared.error(error) }
    }
}

// MARK: - التحكم بالتطبيق
struct AppControlView: View {
    @ObservedObject var store = ConfigStore.shared
    @State private var askStop = false
    var app: JSON { store.v(P("app")) }
    func put(_ k: String, _ v: JSON) {
        var a = app.isObject ? app : ["enabled": true, "message": "", "display": [:]]
        a[k] = v; store.set(P("app"), a)
    }
    var body: some View {
        let on = app["enabled"].bool ?? true
        Page(title: "التحكم بالتطبيق", intro: "أوقف التطبيق لكل المشرفين عند الحاجة، وحدّد مظهره الافتراضي. أنت لا تتأثر بالإيقاف.", id: "app-control") {
            SectionTitle("التشغيل")
            Card {
                HStack(spacing: 12) {
                    Image(systemName: on ? "checkmark.circle.fill" : "pause.circle.fill").font(.system(size: 28)).foregroundStyle(on ? C.ok : C.bad)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(on ? "التطبيق يعمل للمشرفين" : "التطبيق متوقف للمشرفين").font(.ox(16, .semibold)).foregroundStyle(C.ink)
                        Text("يُطبَّق بعد الضغط على «حفظ»").font(.ox(12.5)).foregroundStyle(C.mute)
                    }
                    Spacer()
                }.padding(14)
                ActionRow(title: on ? "إيقاف التطبيق للمشرفين" : "تشغيل التطبيق", icon: on ? "stop.circle" : "play.circle", tone: on ? "bad" : "ok") { if on { askStop = true } else { put("enabled", true) } }
                TextBlock(title: "الرسالة التي تظهر لهم أثناء الإيقاف", text: Binding(get: { app["message"].text }, set: { put("message", .string($0)) }), multiline: true)
            }
            SectionTitle("المظهر الافتراضي للمشرفين")
            Card {
                ChoiceRow(title: "الوضع", options: [("system", "حسب إعداد الجهاز"), ("light", "فاتح"), ("dark", "داكن")],
                          selection: Binding(get: { app["display"]["scheme"].string ?? "system" }, set: { var d = app["display"]; if !d.isObject { d = [:] }; d["scheme"] = .string($0); put("display", d) }))
            }
            SectionFooter("يُطبَّق على المشرفين الذين لا يملكون صلاحية «تغيير مظهر التطبيق لنفسه».")
        }
        .confirmationDialog("إيقاف التطبيق لكل المشرفين؟", isPresented: $askStop, titleVisibility: .visible) {
            Button("إيقاف", role: .destructive) { put("enabled", false) }
        } message: { Text("اضغط «حفظ» بعدها لتطبيق الإيقاف. يمكنك إعادة تشغيله في أي وقت.") }
    }
}

// MARK: - حالة النظام
struct SystemView: View {
    @EnvironmentObject var session: Session
    @StateObject private var r = Remote("/system?bots=1")
    @StateObject private var errs = Remote("/errors")
    @State private var share: ShareItem?
    var body: some View {
        let d = r.data
        Page(title: "حالة النظام", intro: "الخدمات التي يعتمد عليها الموقع وحالتها الآن.", id: "system") {
            RemoteBody(r: r) {
                VStack(spacing: 0) {
                    SectionTitle("الخدمات")
                    Card {
                        InfoRow(title: "تخزين الإعدادات (KV)", value: d["kv"].isTrue ? "يعمل" : "لا يستجيب", tone: d["kv"].isTrue ? "ok" : "bad")
                        InfoRow(title: "قاعدة البيانات (D1)", value: d["d1"].isTrue ? "تعمل" : "لا تستجيب", tone: d["d1"].isTrue ? "ok" : "bad")
                        InfoRow(title: "المهمة المجدولة (Cron)", value: session.status["cron"].date.map { "آخر تشغيل " + Fmt.ago($0) } ?? "غير مفعّلة", tone: session.status["cron"].isNull ? "warn" : "ok")
                        InfoRow(title: "بوت التحكم", value: d["bots"]["control"]["ok"].isTrue ? "مربوط" : "غير مربوط", tone: d["bots"]["control"]["ok"].isTrue ? "ok" : "warn")
                        InfoRow(title: "بوت التذكير", value: d["bots"]["notify"].isNull ? "—" : d["bots"]["notify"]["ok"].isTrue ? "مربوط" : "غير مربوط", tone: d["bots"]["notify"]["ok"].isTrue ? "ok" : "warn")
                    }
                    if session.status["cron"].isNull {
                        Spacer().frame(height: 10)
                        Note(text: "المهمة المجدولة غير مفعّلة، لذلك لن يعمل الفتح التلقائي ولا الإرسال في الخلفية. فعّلها من إعدادات الـWorker في Cloudflare من قسم Trigger Events.", tone: "warn", icon: "exclamationmark.triangle.fill")
                    }
                    SectionTitle("الموقع")
                    Card {
                        InfoRow(title: "إصدار الموقع", value: d["version"].str)
                        InfoRow(title: "رقم البناء", value: d["build"].str)
                        InfoRow(title: "آخر تعديل", value: Fmt.ago(d["updatedAt"].date))
                        InfoRow(title: "النسخ المحفوظة", value: Fmt.n(d["versions"]))
                    }
                    if session.isOwner {
                        SectionTitle("الصيانة")
                        Card {
                            ActionRow(title: "تنزيل نسخة احتياطية", icon: "arrow.down.doc") { do { share = ShareItem(url: try await API.shared.download(API.shared.url("/system/backup"))) } catch { Toasts.shared.error(error) } }
                            ActionRow(title: "إعادة ربط بوتات التيليجرام", icon: "link") { do { try await API.shared.post("/system/webhooks"); Toasts.shared.show("أُعيد ربط البوتات."); await r.load() } catch { Toasts.shared.error(error) } }
                        }
                        SectionFooter("يحتفظ الخادم أيضًا بنسخة احتياطية يومية تلقائيًا.")
                    }
                    SectionTitle("آخر الأخطاء في الموقع")
                    Card {
                        if errs.data["items"].arr.isEmpty { Text("لا توجد أخطاء.").font(.ox(14)).foregroundStyle(C.mute).padding(16) }
                        ForEach(Array(errs.data["items"].arr.prefix(15).enumerated()), id: \.offset) { _, e in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(e["msg"].str).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(C.ink2).lineLimit(3).environment(\.layoutDirection, .leftToRight)
                                Text("\(e["path"].str) · \(Fmt.ago(e["at"].date))").font(.ox(11.5)).foregroundStyle(C.mute)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }
                }
            }
        }
        .task { await r.load(); await errs.load(); await session.refreshStatus() }
        .refreshable { await r.load(); await errs.load() }
        .sheet(item: $share) { s in ShareSheet(items: [s.url]) }
    }
}

// MARK: - الإعدادات
struct SettingsView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var ses = Remote("/me/sessions")
    @State private var icon = UIApplication.shared.alternateIconName ?? "AppIcon"
    @State private var cur = ""
    @State private var next = ""
    static let icons: [(String, String)] = [("AppIcon", "الافتراضية"), ("IconObsidian", "أسود"), ("IconWhite", "أبيض"), ("IconSilver", "فضي"), ("IconSteel", "رمادي"), ("IconClassic", "كلاسيكية"), ("IconMist", "ضبابية"), ("IconOutline", "خطوط"), ("IconBlueprint", "مخطط")]
    var body: some View {
        Page(title: "الإعدادات", intro: "حسابك ومظهر التطبيق على هذا الجهاز.", id: "settings") {
            SectionTitle("الحساب")
            Card {
                InfoRow(title: "الاسم", value: session.name)
                InfoRow(title: "اسم المستخدم", value: "@" + session.me["username"].str)
                InfoRow(title: "الدور", value: session.isOwner ? "المسؤول الرئيسي" : "مشرف")
            }
            SectionTitle("تحديثات التطبيق")
            Card {
                InfoRow(title: "نسختك الحالية", value: "\(Bundle.main.version) · بناء \(Fmt.n(Bundle.main.build))")
                    .accessibilityElement(children: .combine).accessibilityIdentifier("curVer").accessibilityValue(Text(verbatim: "skipped " + String(Session.skippedBuild) + " calls " + String(UserDefaults.standard.integer(forKey: "orvex.dbgSkipCalls")) + " last " + (UserDefaults.standard.string(forKey: "orvex.dbgSkipLast") ?? "-") + " boot " + (UserDefaults.standard.string(forKey: "orvex.dbgBoot") ?? "-") + " ud " + String(UserDefaults.standard.integer(forKey: Session.skippedKey)) + " kc " + (Vault.get("skippedUpdateBuild") ?? "-")))
                if let u = session.availableUpdate {
                    InfoRow(title: "التحديث المتاح", value: "\(u["version"].str) · بناء \(Fmt.n(u["build"]))")
                }
                ActionRow(title: "التحقق من التحديثات", icon: "arrow.triangle.2.circlepath") {
                    if let u = await session.checkForUpdate() { session.pendingUpdate = u }
                    else { Toasts.shared.show("أنت تستخدم أحدث نسخة من التطبيق.") }
                }
                .accessibilityIdentifier("checkUpdate")
            }
            SectionTitle("المظهر")
            if prefs.locked {
                Note(text: "حدّد المسؤول الرئيسي مظهر التطبيق، ولا يمكن تغييره من هنا.", tone: "info", icon: "lock.fill")
            } else {
                Card(padded: true) {
                    Picker("المظهر", selection: $prefs.appearance) { Text("تلقائي").tag("system"); Text("فاتح").tag("light"); Text("داكن").tag("dark") }
                        .pickerStyle(.segmented).accessibilityIdentifier("appearance")
                }
            }
            Spacer().frame(height: 10)
            Card {
                ToggleRow(title: "الأرقام الإنجليزية (123)", sub: "عند الإيقاف تظهر الأرقام العربية (١٢٣)", isOn: $prefs.westernDigits)
                ToggleRow(title: "الاهتزاز عند اللمس", isOn: $prefs.haptics)
            }
            SectionTitle("أيقونة التطبيق")
            Card(padded: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 12)], spacing: 14) {
                    ForEach(SettingsView.icons.indices, id: \.self) { i in
                        let ic = SettingsView.icons[i], on = icon == ic.0
                        Button { setIcon(ic.0) } label: {
                            VStack(spacing: 6) {
                                Image(ic.0 + "Preview").resizable().scaledToFit().frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(on ? C.info : C.line, lineWidth: on ? 2.5 : 1))
                                Text(ic.1).font(.ox(11, on ? .semibold : .regular)).foregroundStyle(on ? C.ink : C.mute)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            SectionTitle("تغيير كلمة المرور")
            Card {
                TextBlock(title: "كلمة المرور الحالية", text: $cur, ltr: true)
                TextBlock(title: "كلمة المرور الجديدة (8 أحرف على الأقل)", text: $next, ltr: true)
                ActionRow(title: "تغيير كلمة المرور", icon: "key.fill") { await changePw() }
            }
            SectionFooter("عند تغييرها يُسجَّل الخروج من أجهزتك الأخرى.")
            SectionTitle("أجهزتك", trailing: Fmt.n(ses.data["sessions"].arr.count))
            Card {
                ForEach(Array(ses.data["sessions"].arr.enumerated()), id: \.offset) { _, s in
                    InfoRow(title: (s["client"].str == "app" ? "التطبيق" : "المتصفح") + (s["current"].isTrue ? " (هذا الجهاز)" : "") + " · " + flag(s["country"].str), value: Fmt.ago(s["last_seen"].date))
                }
                ActionRow(title: "تسجيل الخروج من الأجهزة الأخرى", icon: "iphone.slash", tone: "warn") {
                    _ = try? await API.shared.post("/me/sessions/revoke", ["all": true]); await ses.load(); Toasts.shared.show("سُجّل الخروج من الأجهزة الأخرى.")
                }
            }
        }
        .task { await ses.load() }
    }
    func setIcon(_ name: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(name == "AppIcon" ? nil : name) { err in
            Task { @MainActor in if err == nil { icon = name } else { Toasts.shared.show("تعذّر تغيير الأيقونة.", "bad") } }
        }
    }
    func changePw() async {
        guard next.count >= 8 else { Toasts.shared.show("كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.", "warn"); return }
        do { try await API.shared.post("/me/password", ["current": .string(cur), "next": .string(next)]); cur = ""; next = ""; Toasts.shared.show("تغيّرت كلمة المرور."); await ses.load() }
        catch { Toasts.shared.error(error) }
    }
}

// MARK: - حول التطبيق
struct AboutView: View {
    var body: some View {
        Page(title: "حول التطبيق", id: "about") {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: 0x0B0C0E)).frame(width: 104, height: 104)
                    OrvexSymbol(size: 58, color: .white)
                }.padding(.top, 20)
                OrvexWordmark(height: 16)
                Text("POWERING POSSIBILITIES").font(.num(10, .medium)).tracking(3).foregroundStyle(C.mute)
            }.frame(maxWidth: .infinity)
            Spacer().frame(height: 22)
            Card {
                InfoRow(title: "الإصدار", value: "\(Bundle.main.version) (بناء \(Fmt.n(Bundle.main.build)))")
                InfoRow(title: "الخادم", value: API.shared.base.replacingOccurrences(of: "https://", with: ""))
            }
            VStack(spacing: 5) {
                Text("تصميم وتطوير ياسين محمد").font(.ox(15, .semibold)).foregroundStyle(C.ink)
                Text("ORVEX © " + String(Calendar.current.component(.year, from: Date()))).font(.num(11, .medium)).foregroundStyle(C.mute)
            }.frame(maxWidth: .infinity).padding(.top, 26)
        }
    }
}
