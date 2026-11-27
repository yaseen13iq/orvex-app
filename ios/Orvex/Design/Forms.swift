import SwiftUI

// MARK: - تعريف النماذج
/// نوع الحقل
enum FieldKind {
    case text            // سطر واحد (يدعم العربية والإنجليزية)
    case long            // نص طويل
    case toggle
    case number(String?) // رقم مع وحدة اختيارية
    case money(String)   // IQD أو USD
    case date
    case url
    case choice([(String, String)])
    case dynamicChoice(@MainActor () -> [(String, String)])
    case plain           // نص لا يُترجم (مثل معرّف أو رمز)
}

struct Field {
    var key: [Seg]
    var label: String
    var help: String? = nil
    var kind: FieldKind = .text
    var placeholder: String? = nil
    init(_ key: String, _ label: String, _ kind: FieldKind = .text, help: String? = nil, placeholder: String? = nil) {
        self.key = key.split(separator: ".").map { Seg.key(String($0)) }
        self.label = label; self.kind = kind; self.help = help; self.placeholder = placeholder
    }
}

struct FormSection {
    var title: String?
    var footer: String? = nil
    var fields: [Field]
    /// يظهر القسم فقط إذا كان هذا المفتاح مفعّلًا
    var showIf: String? = nil
    init(_ title: String?, footer: String? = nil, showIf: String? = nil, _ fields: [Field]) { self.title = title; self.footer = footer; self.fields = fields; self.showIf = showIf }
}

/// لغة التحرير للنصوص ثنائية اللغة
struct EditLangKey: EnvironmentKey { static let defaultValue = "ar" }
extension EnvironmentValues { var editLang: String { get { self[EditLangKey.self] } set { self[EditLangKey.self] = newValue } } }

/// مفتاح اختيار لغة النصوص أعلى الصفحة
struct LangSwitch: View {
    @Binding var lang: String
    var body: some View {
        Picker("لغة النصوص", selection: $lang) {
            Text("النصوص العربية").tag("ar")
            Text("English").tag("en")
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16).padding(.top, 6)
        .accessibilityIdentifier("langSwitch")
    }
}

// MARK: - عرض النموذج
struct FormSections: View {
    var base: [Seg]
    var sections: [FormSection]
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        ForEach(sections.indices, id: \.self) { si in
            let sec = sections[si]
            if visible(sec) {
                if let t = sec.title { SectionTitle(t) } else { Spacer().frame(height: 14) }
                Card {
                    ForEach(sec.fields.indices, id: \.self) { fi in
                        FieldView(path: base + sec.fields[fi].key, field: sec.fields[fi])
                    }
                }
                if let f = sec.footer { SectionFooter(f) }
            }
        }
    }
    func visible(_ s: FormSection) -> Bool {
        guard let k = s.showIf else { return true }
        let p = base + k.split(separator: ".").map { Seg.key(String($0)) }
        return store.v(p).isTrue
    }
}

struct FieldView: View {
    var path: [Seg]
    var field: Field
    @ObservedObject var store = ConfigStore.shared
    @Environment(\.editLang) var lang

    var body: some View {
        switch field.kind {
        case .toggle:
            ToggleRow(title: field.label, sub: field.help, isOn: store.bool(path))
        case .number(let unit):
            NumberFieldRow(title: field.label, help: field.help, unit: unit, value: store.number(path))
        case .money(let cur):
            NumberFieldRow(title: field.label, help: field.help, unit: cur == "USD" ? "$" : "د.ع", value: store.number(path), grouping: true)
        case .date:
            DateFieldRow(title: field.label, help: field.help, path: path)
        case .dynamicChoice(let fn):
            ChoiceRow(title: field.label, help: field.help, options: fn(), selection: Binding(get: { store.v(path).str }, set: { store.set(path, .string($0)) }))
        case .choice(let opts):
            ChoiceRow(title: field.label, help: field.help, options: opts, selection: Binding(get: { store.v(path).str }, set: { store.set(path, .string($0)) }))
        case .url, .plain:
            TextBlock(title: field.label, help: field.help, placeholder: field.placeholder ?? (isURL ? "https://" : ""), text: store.text(path), ltr: true, multiline: false, keyboard: isURL ? .URL : .default)
        case .long, .text:
            let v = store.v(path)
            let i18n = v.isI18n || v.isNull || v.isObject
            TextBlock(title: field.label + (i18n && lang == "en" ? " (English)" : ""), help: field.help, placeholder: field.placeholder ?? "",
                      text: i18n ? store.text(path, lang: lang) : store.text(path), ltr: i18n && lang == "en", multiline: isLong)
        }
    }
    var isURL: Bool { if case .url = field.kind { return true }; return false }
    var isLong: Bool { if case .long = field.kind { return true }; return false }
}

// MARK: - مكوّنات الحقول
struct TextBlock: View {
    var title: String
    var help: String? = nil
    var placeholder: String = ""
    @Binding var text: String
    var ltr = false
    var multiline = false
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.ox(13, .medium)).foregroundStyle(C.mute)
            Group {
                if multiline {
                    TextField(placeholder, text: $text, axis: .vertical).lineLimit(3...14)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.ox(15.5))
            .keyboardType(keyboard)
            .textInputAutocapitalization(ltr ? .never : .sentences)
            .autocorrectionDisabled(ltr)
            .multilineTextAlignment(ltr ? .leading : .leading)
            .environment(\.layoutDirection, ltr ? .leftToRight : .rightToLeft)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(C.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let h = help { Text(h).font(.ox(12)).foregroundStyle(C.mute).lineSpacing(1) }
        }
        .padding(14)
    }
}

struct NumberFieldRow: View {
    var title: String
    var help: String? = nil
    var unit: String? = nil
    @Binding var value: Double
    var grouping = false
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title).font(.ox(15.5, .medium)).foregroundStyle(C.ink)
                Spacer()
                HStack(spacing: 6) {
                    TextField("0", text: $text)
                        .keyboardType(.decimalPad).multilineTextAlignment(.center)
                        .font(.ox(15.5, .semibold)).focused($focused)
                        .frame(minWidth: 70, maxWidth: 140)
                        .environment(\.layoutDirection, .leftToRight)
                    if let u = unit { Text(u).font(.ox(13)).foregroundStyle(C.mute) }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(C.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if let h = help { Text(h).font(.ox(12)).foregroundStyle(C.mute) }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .onAppear { text = show(value) }
        .onChange(of: value) { _, v in if !focused { text = show(v) } }
        .onChange(of: text) { _, t in
            let clean = t.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "٬", with: "")
                .map { c -> Character in if let d = "٠١٢٣٤٥٦٧٨٩".firstIndex(of: c) { return Character(String("٠١٢٣٤٥٦٧٨٩".distance(from: "٠١٢٣٤٥٦٧٨٩".startIndex, to: d))) }; return c }
            if let d = Double(String(clean)), d != value { value = d }
        }
        .onChange(of: focused) { _, f in if !f { text = show(value) } }
    }
    func show(_ v: Double) -> String {
        if grouping { let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "en_US"); f.maximumFractionDigits = 2; return f.string(from: NSNumber(value: v)) ?? "\(v)" }
        return v == v.rounded() ? String(Int(v)) : String(v)
    }
}

struct DateFieldRow: View {
    var title: String
    var help: String? = nil
    var path: [Seg]
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let has = store.v(path).date != nil
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { has }, set: { on in
                store.set(path, on ? .number(((Date().addingTimeInterval(86400).timeIntervalSince1970 / 3600).rounded(.up) * 3600 * 1000)) : .null)
            })) {
                Text(title).font(.ox(15.5, .medium)).foregroundStyle(C.ink)
            }.toggleStyle(SwitchToggleStyle(tint: C.ok))
            if has {
                DatePicker("", selection: store.date(path), displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden().environment(\.timeZone, Fmt.baghdad).environment(\.locale, Locale(identifier: "ar_IQ"))
                Text(Fmt.date(store.v(path).date) + " — بتوقيت بغداد").font(.ox(12)).foregroundStyle(C.mute)
            }
            if let h = help { Text(h).font(.ox(12)).foregroundStyle(C.mute) }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}

struct ChoiceRow: View {
    var title: String
    var help: String? = nil
    var options: [(String, String)]
    @Binding var selection: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.ox(15.5, .medium)).foregroundStyle(C.ink)
                Spacer()
                Menu {
                    ForEach(options.indices, id: \.self) { i in
                        Button { selection = options[i].0 } label: {
                            if selection == options[i].0 { Label(options[i].1, systemImage: "checkmark") } else { Text(options[i].1) }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(options.first { $0.0 == selection }?.1 ?? "اختر").font(.ox(14.5))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(C.ink2)
                }
            }
            if let h = help { Text(h).font(.ox(12)).foregroundStyle(C.mute) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 54)
    }
}

// MARK: - صفحة نموذج كاملة
struct FormPage: View {
    var def: FormDef
    var base: [Seg]
    @State private var lang = "ar"
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        Page(title: def.title, intro: def.intro, id: def.id) {
            if !store.loaded { LoadingView() } else {
                if def.bilingual { LangSwitch(lang: $lang) }
                if let pv = def.preview { pv(base).padding(.top, 14) }
                FormSections(base: base, sections: def.sections).environment(\.editLang, lang)
                ForEach(def.lines.indices, id: \.self) { i in
                    let l = def.lines[i]
                    StringListEditor(title: l.0, path: base + l.1.split(separator: ".").map { Seg.key(String($0)) }, addLabel: l.2).environment(\.editLang, lang)
                }
                if let more = def.links, !more.isEmpty {
                    SectionTitle("المزيد")
                    Card {
                        ForEach(more.indices, id: \.self) { i in
                            let l = more[i]
                            NavRow(value: l.route(base), title: l.title, sub: l.sub, icon: l.icon, color: l.color)
                        }
                    }
                }
            }
        }
    }
}

/// رابط إلى قائمة أو نموذج فرعي
struct FormLink {
    var title: String
    var sub: String? = nil
    var icon: String
    var color: String = "graphite"
    var route: ([Seg]) -> AnyHashableRoute
}

struct FormDef {
    var id: String
    var title: String
    var intro: String? = nil
    var bilingual = true
    var sections: [FormSection]
    var links: [FormLink]? = nil
    var preview: (([Seg]) -> AnyView)? = nil
    /// قوائم نصوص بسيطة تظهر بعد الأقسام: (العنوان، المفتاح، نص زر الإضافة)
    var lines: [(String, String, String)] = []
}

/// المسارات العامة للتنقّل داخل التطبيق
enum AnyHashableRoute: Hashable {
    case form(String, [Seg])
    case list(String, [Seg])
    case screen(String)
}


// MARK: - تعريف القوائم
struct ListDef {
    var id: String
    var title: String
    var intro: String? = nil
    var itemForm: String
    var addLabel: String
    var template: JSON
    var itemTitle: (JSON) -> String
    var itemSub: (JSON) -> String? = { _ in nil }
    /// مفتاح «ظاهر» داخل العنصر إن وجد
    var enabledKey: String? = "enabled"
}

struct ListPage: View {
    var def: ListDef
    var path: [Seg]
    @ObservedObject var store = ConfigStore.shared
    @State private var editing = false
    @State private var askDelete: Int? = nil
    var items: [JSON] { store.v(path).arr }
    var body: some View {
        Page(title: def.title, intro: def.intro, id: def.id) {
            if !store.loaded { LoadingView() } else {
                SectionTitle(items.isEmpty ? "لا توجد عناصر بعد" : (items.count == 1 ? "عنصر واحد" : "\(Fmt.n(items.count)) عناصر"), trailing: items.count > 1 ? (editing ? nil : "اضغط «ترتيب» لتغيير الترتيب") : nil)
                if !items.isEmpty {
                    Card {
                        ForEach(items.indices, id: \.self) { i in
                            HStack(spacing: 0) {
                                if editing {
                                    VStack(spacing: 2) {
                                        Button { move(i, -1) } label: { Image(systemName: "chevron.up").frame(width: 34, height: 26) }.disabled(i == 0)
                                        Button { move(i, 1) } label: { Image(systemName: "chevron.down").frame(width: 34, height: 26) }.disabled(i == items.count - 1)
                                    }.foregroundStyle(C.ink2).padding(.leading, 8)
                                }
                                NavigationLink(value: AnyHashableRoute.form(def.itemForm, path + [.index(i)])) {
                                    RowContent(title: title(i), sub: def.itemSub(items[i]),
                                               pill: hidden(i) ? ("مخفي", "mute") : nil)
                                }.buttonStyle(RowPress())
                                if editing {
                                    Button { askDelete = i } label: { Image(systemName: "trash").foregroundStyle(C.bad).frame(width: 44, height: 44) }
                                        .accessibilityLabel("حذف")
                                }
                            }
                        }
                    }
                }
                Spacer().frame(height: 14)
                HStack(spacing: 10) {
                    PrimaryButton(title: def.addLabel, icon: "plus") { add() }
                    if items.count > 1 || editing {
                        Button { withAnimation(.snappy) { editing.toggle() } } label: {
                            Text(editing ? "تم" : "ترتيب وحذف").font(.ox(15, .medium)).foregroundStyle(C.ink)
                                .padding(.horizontal, 18).frame(height: 52).background(C.card, in: Capsule())
                        }.buttonStyle(.plain).padding(.trailing, 16)
                    }
                }
            }
        }
        .confirmationDialog("حذف «\(askDelete.map { title($0) } ?? "")»؟", isPresented: Binding(get: { askDelete != nil }, set: { if !$0 { askDelete = nil } }), titleVisibility: .visible) {
            Button("حذف", role: .destructive) { if let i = askDelete { remove(i) } }
        } message: { Text("يُحذف بعد الضغط على «حفظ»، ويمكنك التراجع من سجل التعديلات.") }
    }
    func title(_ i: Int) -> String { let t = def.itemTitle(items[i]); return t.isEmpty ? "عنصر \(Fmt.n(i + 1))" : t }
    func hidden(_ i: Int) -> Bool { guard let k = def.enabledKey else { return false }; return items[i][k].bool == false }
    func add() {
        var a = items
        var t = def.template
        if t.isObject && t["id"].isNull == false { t["id"] = .string(String(t["id"].str.prefix(1)) + String(Int(Date().timeIntervalSince1970) % 100000)) }
        a.append(t)
        store.set(path, .array(a)); store.structural(path)
        Haptics.tap()
    }
    func remove(_ i: Int) {
        var a = items; guard i < a.count else { return }
        a.remove(at: i); store.set(path, .array(a)); store.structural(path)
    }
    func move(_ i: Int, _ d: Int) {
        var a = items; let j = i + d; guard j >= 0, j < a.count else { return }
        a.swapAt(i, j); store.set(path, .array(a)); store.structural(path); Haptics.tap()
    }
}

// MARK: - قائمة نصوص بسيطة (مثل المزايا)
struct StringListEditor: View {
    var title: String
    var path: [Seg]
    var addLabel = "إضافة سطر"
    @ObservedObject var store = ConfigStore.shared
    @Environment(\.editLang) var lang
    var body: some View {
        let items = store.v(path).arr
        SectionTitle(title, trailing: Fmt.n(items.count))
        Card {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 8) {
                    Text(Fmt.n(i + 1) + ".").font(.ox(13)).foregroundStyle(C.mute).padding(.top, 12)
                    TextField("", text: binding(i), axis: .vertical).lineLimit(1...6).font(.ox(15))
                        .environment(\.layoutDirection, lang == "en" ? .leftToRight : .rightToLeft)
                        .padding(.vertical, 10)
                    Button { var a = items; a.remove(at: i); store.set(path, .array(a)); store.structural(path) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(C.bad).padding(.top, 10)
                    }.buttonStyle(.plain).accessibilityLabel("حذف السطر")
                }.padding(.horizontal, 14)
            }
            Button {
                var a = items; a.append(store.v(path + [.index(0)]).isI18n || items.isEmpty ? .i18n("") : .string(""))
                store.set(path, .array(a)); store.structural(path)
            } label: {
                Label(addLabel, systemImage: "plus.circle.fill").font(.ox(15, .medium)).foregroundStyle(C.info)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(minHeight: 50)
            }.buttonStyle(.plain)
        }
    }
    func binding(_ i: Int) -> Binding<String> {
        let p = path + [.index(i)]
        return store.v(p).isI18n ? store.text(p, lang: lang) : store.text(p)
    }
}
