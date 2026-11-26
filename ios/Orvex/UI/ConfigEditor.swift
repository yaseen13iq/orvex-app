import SwiftUI

/// صفحة تحرير لأي كائن بإعدادات الموقع
struct ConfigPage: View {
    let path: [Seg]
    let title: String
    var keys: [String]? = nil
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        let v = store.v(path)
        Group {
            if !store.loaded { Loading() }
            else if v.isArray { ArrayPage(path: path, title: title) }
            else {
                Form {
                    ConfigFields(path: path, keys: keys)
                }
                .formStyle(.grouped)
            }
        }
        .oxScreen(title, page: "edit:" + path.map(\.description).joined(separator: "."))
    }
}

/// الحقول داخل Form
struct ConfigFields: View {
    let path: [Seg]
    var keys: [String]? = nil
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let v = store.v(path)
        let all = keys ?? v.keys
        let ordered = all.sorted { (a, b) in (a == "enabled" ? 0 : 1) < (b == "enabled" ? 0 : 1) }
        let simple = ordered.filter { k in let c = v[k]; return !(c.isObject && !c.isI18n) && !c.isArray }
        let nested = ordered.filter { k in let c = v[k]; return (c.isObject && !c.isI18n) || c.isArray }
        let visibleSimple = simple.filter { visible(path + [.key($0)]) }
        let visibleNested = nested.filter { visible(path + [.key($0)]) }
        if !visibleSimple.isEmpty {
            Section {
                ForEach(visibleSimple, id: \.self) { k in FieldRow(path: path + [.key(k)]) }
            }
        }
        if !visibleNested.isEmpty {
            Section {
                ForEach(visibleNested, id: \.self) { k in NestedLink(path: path + [.key(k)]) }
            }
        }
    }
    func visible(_ p: [Seg]) -> Bool {
        guard let k = p.last?.keyName, !Labels.hiddenKeys.contains(k) else { return false }
        return store.canPath(p)
    }
}

struct NestedLink: View {
    let path: [Seg]
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let v = store.v(path), key = path.last?.description ?? ""
        let label = Labels.label(key, path)
        NavigationLink(value: EditRoute(path: path, title: label)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.ox(15, .medium))
                    if v.isArray { Text("\(Fmt.n(v.arr.count)) عنصر").font(.ox(12)).foregroundStyle(.secondary) }
                    else if let en = v["enabled"].bool { Text(en ? "ظاهر" : "مخفي").font(.ox(12)).foregroundStyle(en ? .green : .secondary) }
                }
                Spacer()
                if store.isDirty(path) { Circle().fill(Prefs.shared.theme.accent).frame(width: 8, height: 8) }
            }
        }
    }
}

/// سطر حقل واحد حسب نوعه
struct FieldRow: View {
    let path: [Seg]
    var label: String? = nil
    var hint: String? = nil
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared

    var key: String { path.last?.description ?? "" }
    var title: String { label ?? Labels.label(key, path) }

    var body: some View {
        let v = store.v(path)
        let dirty = store.isDirty(path)
        Group {
            if v.isI18n { I18nField(path: path, title: title, hint: hint ?? Labels.hint(path)) }
            else if v.bool != nil {
                Toggle(isOn: store.bool(path)) { titleView(dirty) }
            } else if let opts = Labels.options(path), v.string != nil || v.double != nil {
                OptionField(path: path, title: title, options: opts, dirty: dirty)
            } else if Labels.dateKeys.contains(key) {
                DateField(path: path, title: title, dirty: dirty)
            } else if v.double != nil || (v.isNull && ["priceIQD", "priceUSD"].contains(key)) {
                NumberField(path: path, title: title, dirty: dirty, nullable: ["priceIQD", "priceUSD"].contains(key))
            } else {
                StringField(path: path, title: title, hint: hint ?? Labels.hint(path), dirty: dirty)
            }
        }
        .font(.ox(15))
    }
    func titleView(_ dirty: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.ox(15))
            if dirty { Circle().fill(prefs.theme.accent).frame(width: 7, height: 7) }
        }
    }
}

struct FieldTitle: View {
    let title: String
    var hint: String? = nil
    var dirty = false
    var trailing: AnyView? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.ox(14, .semibold)).foregroundStyle(prefs.theme.ink)
            if dirty { Circle().fill(prefs.theme.accent).frame(width: 7, height: 7) }
            Spacer(minLength: 0)
            if let tr = trailing { tr }
        }
        if let h = hint, !h.isEmpty { Text(h).font(.ox(12)).foregroundStyle(prefs.theme.mute) }
    }
}

struct I18nField: View {
    let path: [Seg]
    let title: String
    var hint: String? = nil
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var canHide: Bool { !["texts", "notify", "mood"].contains(path.first?.keyName ?? "") }
    var body: some View {
        let hidden = store.hidden(path)
        VStack(alignment: .leading, spacing: 8) {
            FieldTitle(title: title, hint: hidden ? "مخفي من الموقع" : hint, dirty: store.isDirty(path), trailing: canHide ? AnyView(
                Button { store.toggleHidden(path); prefs.tap() } label: { Image(systemName: hidden ? "eye.slash.fill" : "eye").foregroundStyle(hidden ? prefs.theme.warn : prefs.theme.mute) }
                    .buttonStyle(.borderless).accessibilityLabel(hidden ? "أظهره بالموقع" : "اخفيه من الموقع")
            ) : nil)
            TextField("عربي", text: store.text(path, lang: "ar"), axis: .vertical)
                .lineLimit(1...8).font(.ox(15))
                .padding(10).background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            TextField("English", text: store.text(path, lang: "en"), axis: .vertical)
                .lineLimit(1...8).font(.ox(14))
                .environment(\.layoutDirection, .leftToRight)
                .padding(10).background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .opacity(hidden ? 0.6 : 1)
        .padding(.vertical, 4)
    }
}

struct StringField: View {
    let path: [Seg]
    let title: String
    var hint: String? = nil
    var dirty = false
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @Environment(\.openURL) var openURL
    var body: some View {
        let isURL = Labels.isURL(path.last?.description ?? "")
        let val = store.v(path).str
        VStack(alignment: .leading, spacing: 8) {
            FieldTitle(title: title, hint: hint, dirty: dirty, trailing: isURL && val.hasPrefix("http") ? AnyView(Button { if let u = URL(string: val) { openURL(u) } } label: { Image(systemName: "arrow.up.forward.square") }.buttonStyle(.borderless)) : nil)
            TextField(title, text: store.text(path), axis: .vertical)
                .lineLimit(1...6)
                .textInputAutocapitalization(isURL ? .never : .sentences)
                .autocorrectionDisabled(isURL)
                .keyboardType(isURL ? .URL : .default)
                .environment(\.layoutDirection, isURL || val.allSatisfy({ $0.isASCII }) && !val.isEmpty ? .leftToRight : .rightToLeft)
                .padding(10).background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.padding(.vertical, 4)
    }
}

struct NumberField: View {
    let path: [Seg]
    let title: String
    var dirty = false
    var nullable = false
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        let v = store.v(path)
        VStack(alignment: .leading, spacing: 8) {
            FieldTitle(title: title, hint: (v.double ?? 0) >= 1000 ? Fmt.n(v) : (nullable && v.isNull ? "فارغ = حسب الطلب" : nil), dirty: dirty)
            TextField(nullable ? "فارغ" : "0", text: $text)
                .keyboardType(.decimalPad).focused($focused)
                .environment(\.layoutDirection, .leftToRight)
                .font(.num(16, .medium))
                .padding(10).background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: text) { _, t in
                    let clean = t.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "٬", with: "")
                    if clean.isEmpty { store.set(path, nullable ? .null : .number(0)) }
                    else if let d = Double(clean) { store.set(path, .number(d)) }
                }
        }
        .padding(.vertical, 4)
        .onAppear { text = v.double.map { JSON.fmt($0) } ?? "" }
        .onChange(of: store.v(path)) { _, nv in if !focused { text = nv.double.map { JSON.fmt($0) } ?? "" } }
    }
}

struct DateField: View {
    let path: [Seg]
    let title: String
    var dirty = false
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let v = store.v(path)
        VStack(alignment: .leading, spacing: 8) {
            FieldTitle(title: title, hint: v.date.map { ($0 < Date() ? "فات الموعد · " : "") + "بغداد: " + Fmt.date($0) } ?? "بدون موعد", dirty: dirty)
            if v.date != nil {
                HStack {
                    DatePicker("", selection: store.date(path)).labelsHidden()
                    Spacer()
                    Button(role: .destructive) { store.set(path, .null) } label: { Label("امسح", systemImage: "xmark.circle") }.buttonStyle(.borderless).font(.ox(13))
                }
            } else {
                Button { store.set(path, .number((Date().addingTimeInterval(86400).timeIntervalSince1970 * 1000).rounded())) } label: { Label("حدد موعد", systemImage: "calendar.badge.plus") }.buttonStyle(.borderless)
            }
        }.padding(.vertical, 4)
    }
}

struct OptionField: View {
    let path: [Seg]
    let title: String
    let options: [(JSON, String)]
    var dirty = false
    @ObservedObject var store = ConfigStore.shared
    var body: some View {
        let cur = store.v(path)
        if options.count <= 3 {
            VStack(alignment: .leading, spacing: 8) {
                FieldTitle(title: title, dirty: dirty)
                Picker(title, selection: Binding(get: { JSONCodec.string(cur) }, set: { s in if let o = options.first(where: { JSONCodec.string($0.0) == s }) { store.set(path, o.0) } })) {
                    ForEach(options.indices, id: \.self) { i in Text(options[i].1).tag(JSONCodec.string(options[i].0)) }
                }.pickerStyle(.segmented)
            }.padding(.vertical, 4)
        } else {
            Picker(selection: Binding(get: { JSONCodec.string(cur) }, set: { s in if let o = options.first(where: { JSONCodec.string($0.0) == s }) { store.set(path, o.0) } })) {
                if !options.contains(where: { $0.0 == cur }) { Text(cur.str).tag(JSONCodec.string(cur)) }
                ForEach(options.indices, id: \.self) { i in Text(options[i].1).tag(JSONCodec.string(options[i].0)) }
            } label: {
                HStack(spacing: 6) { Text(title); if dirty { Circle().fill(Prefs.shared.theme.accent).frame(width: 7, height: 7) } }
            }
        }
    }
}

// MARK: - القوائم
struct ArrayPage: View {
    let path: [Seg]
    let title: String
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var confirmDelete: Int?

    var body: some View {
        let arr = store.v(path).arr
        let simple = arr.isEmpty ? ArrayTemplates.newItem(path).isI18n : arr.allSatisfy(\.isI18n)
        let ro = !store.canPath(path)
        List {
            if arr.isEmpty { EmptyState(icon: "tray", text: "فاضي", sub: ro ? nil : "اضغط + حتى تضيف").listRowBackground(Color.clear) }
            ForEach(Array(arr.enumerated()), id: \.offset) { i, it in
                if simple {
                    VStack(spacing: 8) {
                        TextField("عربي", text: store.text(path + [.index(i)], lang: "ar"), axis: .vertical).font(.ox(15))
                        TextField("English", text: store.text(path + [.index(i)], lang: "en"), axis: .vertical).font(.ox(14)).environment(\.layoutDirection, .leftToRight).foregroundStyle(prefs.theme.ink2)
                    }
                    .disabled(ro)
                    .swipeActions { if !ro { rowActions(i) } }
                } else {
                    NavigationLink(value: EditRoute(path: path + [.index(i)], title: Labels.itemTitle(it, i))) {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.num(12)).foregroundStyle(prefs.theme.mute).frame(width: 26, height: 26).background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Labels.itemTitle(it, i)).font(.ox(15, .medium)).lineLimit(2)
                                    .strikethrough(it["enabled"].bool == false || it["on"].bool == false)
                                    .foregroundStyle(it["enabled"].bool == false || it["on"].bool == false ? prefs.theme.mute : prefs.theme.ink)
                            }
                            Spacer()
                            if store.isDirty(path + [.index(i)]) { Circle().fill(prefs.theme.accent).frame(width: 8, height: 8) }
                        }
                    }
                    .swipeActions { if !ro { rowActions(i) } }
                }
            }
            .onMove { from, to in
                var a = store.v(path).arr
                a.move(fromOffsets: from, toOffset: to)
                store.set(path, .array(a)); store.structural(path)
            }
            .moveDisabled(ro)
        }
        .listStyle(.insetGrouped)
        .oxScreen(title)
        .toolbar {
            if !ro {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button { add() } label: { Image(systemName: "plus") }.accessibilityLabel("أضف")
                }
            }
        }
        .confirmationDialog("تحذف هذا العنصر؟", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            Button("احذف", role: .destructive) { if let i = confirmDelete { remove(i) } }
        }
    }
    @ViewBuilder func rowActions(_ i: Int) -> some View {
        Button(role: .destructive) { confirmDelete = i } label: { Label("حذف", systemImage: "trash") }
        Button { duplicate(i) } label: { Label("نسخة", systemImage: "plus.square.on.square") }.tint(.gray)
    }
    func add() {
        var a = store.v(path).arr
        a.append(ArrayTemplates.newItem(path))
        store.set(path, .array(a)); store.structural(path)
        prefs.tap()
    }
    func duplicate(_ i: Int) {
        var a = store.v(path).arr
        var c = a[i]
        if c["id"].string != nil { c["id"] = .string(ArrayTemplates.uid(String(c["id"].str.prefix(1)))) }
        a.insert(c, at: i + 1)
        store.set(path, .array(a)); store.structural(path)
    }
    func remove(_ i: Int) {
        var a = store.v(path).arr
        guard i < a.count else { return }
        a.remove(at: i)
        store.set(path, .array(a)); store.structural(path)
    }
}

enum ArrayTemplates {
    static func uid(_ p: String) -> String { p + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + String(Int.random(in: 100...999)) }
    static func blank(_ x: JSON) -> JSON {
        if x.isI18n { return .i18n("") }
        switch x {
        case .array: return .array([])
        case .object(let o):
            var n = JObject()
            for (k, v) in o.pairs { n[k] = k == "id" ? .string(uid(String(v.str.prefix(1)))) : k == "enabled" ? .bool(true) : blank(v) }
            return .object(n)
        case .string: return .string("")
        default: return x
        }
    }
    @MainActor static func newItem(_ path: [Seg]) -> JSON {
        let p = Labels.pattern(path), arr = ConfigStore.shared.v(path).arr
        switch p {
        case "gallery.items": return ["id": .string(uid("g")), "enabled": false, "before": "", "after": "", "caption": .i18n(""), "tag": .i18n("")]
        case "faq": return ["id": .string(uid("f")), "enabled": true, "q": .i18n(""), "a": .i18n("")]
        case "changelog.items": return ["id": .string(uid("c")), "enabled": true, "text": .i18n("")]
        case "counters": return ["id": .string(uid("n")), "enabled": true, "value": 0, "prefix": "+", "label": .i18n("")]
        case "goals.items": return ["id": .string(uid("g")), "icon": "⭐", "name": .i18n(""), "body": .i18n("")]
        case "steps.items": return ["id": .string(uid("s")), "n": "", "name": .i18n(""), "body": .i18n("")]
        case "geo.countries", "geo.ips": return ""
        default: break
        }
        if p.hasPrefix("mood.list.") { return ["id": .string(uid("m")), "ar": "", "en": "", "on": true] }
        if p == "plans", let last = arr.last {
            var b = last; b["id"] = .string(uid("p")); b["title"] = .i18n("باقة جديدة", "New plan"); b["featured"] = false; b["enabled"] = false
            return b
        }
        if let last = arr.last { return blank(last) }
        return .i18n("")
    }
}
