import SwiftUI

/// حظر الدول وعناوين IP
struct GeoView: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var stats = Remote("/geo/stats?days=7")
    @StateObject private var me = Remote("/geo/me")
    @State private var pickCountries = false
    @State private var ipInput = ""
    @State private var ipBad: [String] = []
    @State private var mineWarn = false

    static let defaults: JSON = ["enabled": false, "countries": [], "ips": [], "action": "block", "message": ["ar": "الموقع غير متاح في منطقتك.", "en": "This site isn't available in your region."], "redirect": "", "exemptAdmin": true]
    var g: JSON { store.v(P("geo")) }

    /// يتأكد إن قسم الحظر موجود قبل أي تعديل
    func ensure() { if !g.isObject { store.set(P("geo"), GeoView.defaults) } }
    func put(_ k: String, _ v: JSON) {
        ensure()
        var n = store.v(P("geo"))
        for (dk, dv) in GeoView.defaults.object!.pairs where n[dk].isNull { n[dk] = dv }
        n[k] = v
        store.set(P("geo"), n)
    }

    var body: some View {
        let t = prefs.theme
        Form {
            Section {
                Toggle(isOn: Binding(get: { g["enabled"].isTrue }, set: { put("enabled", .bool($0)) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("الحظر شغّال").font(.ox(16, .semibold))
                        Text("\(Fmt.n(g["countries"].arr.count)) دولة · \(Fmt.n(g["ips"].arr.count)) عنوان").font(.ox(12.5)).foregroundStyle(t.mute)
                    }
                }.accessibilityIdentifier("geoEnabled")
                if me.loaded {
                    HStack {
                        Text("عنوانك هسه").font(.ox(13)).foregroundStyle(t.mute)
                        Spacer()
                        Text("\(flag(me.data["country"].str)) \(me.data["ip"].str)").font(.num(13, .regular)).textSelection(.enabled)
                    }
                    if g["countries"].arr.contains(where: { $0.str == me.data["country"].str }) && g["exemptAdmin"].bool == false {
                        Label("انتبه: دولتك محظورة واللوحة مو مستثناة — راح تنحظر انت هم", systemImage: "exclamationmark.triangle.fill").font(.ox(12.5)).foregroundStyle(t.bad)
                    }
                }
            } footer: { Text("الزائر المحظور يشوف صفحة 403 بسيطة. بوتات التيليجرام ما تتأثر أبدًا.").font(.ox(12)) }

            Section {
                ForEach(g["countries"].arr.map(\.str), id: \.self) { cc in
                    HStack {
                        Text(flag(cc)).font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(countryName(cc)).font(.ox(15))
                            Text(cc).font(.num(11, .regular)).foregroundStyle(t.mute)
                        }
                        Spacer()
                        if let n = stats.data["byCountry"][cc].double, n > 0 { Pill(text: "\(Fmt.n(n)) محاولة", tone: "warn") }
                    }
                }
                .onDelete { idx in
                    var a = g["countries"].arr; a.remove(atOffsets: idx); put("countries", .array(a))
                }
                Button { pickCountries = true } label: { Label("أضف دولة", systemImage: "plus.circle.fill").font(.ox(15)) }
            } header: { Text("الدول المحظورة") } footer: { Text("اسحب لليسار للحذف").font(.ox(12)) }

            Section {
                ForEach(Array(g["ips"].arr.enumerated()), id: \.offset) { _, ip in
                    HStack {
                        Image(systemName: ip.str.contains(":") ? "6.circle" : "4.circle").foregroundStyle(t.mute)
                        Text(ip.str).font(.system(size: 15, design: .monospaced)).environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        if ip.str.contains("/") { Pill(text: "نطاق") }
                    }
                }
                .onDelete { idx in var a = g["ips"].arr; a.remove(atOffsets: idx); put("ips", .array(a)) }
                HStack {
                    TextField("مثل 1.2.3.4 أو 1.2.3.0/24", text: $ipInput)
                        .font(.system(size: 15, design: .monospaced)).keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                        .onSubmit { Task { await addIPs() } }
                    AsyncButton(action: { await addIPs() }) { Text("أضف").font(.ox(14, .semibold)) }.buttonStyle(.borderless).disabled(ipInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !ipBad.isEmpty { Text("غير صالحة: " + ipBad.joined(separator: "، ")).font(.ox(12.5)).foregroundStyle(t.bad) }
                if mineWarn { Label("هذا يشمل عنوانك الحالي", systemImage: "exclamationmark.triangle.fill").font(.ox(12.5)).foregroundStyle(t.warn) }
            } header: { Text("عناوين IP") } footer: { Text("تكدر تلصق أكثر من عنوان مفصولة بفاصلة أو سطر. يدعم IPv4 وIPv6 والنطاقات (CIDR).").font(.ox(12)) }

            Section {
                Picker("الإجراء", selection: Binding(get: { g["action"].string ?? "block" }, set: { put("action", .string($0)) })) {
                    Text("صفحة حظر 403").tag("block")
                    Text("تحويل لرابط ثاني").tag("redirect")
                }.font(.ox(15))
                if g["action"].string == "redirect" {
                    TextField("https://…", text: Binding(get: { g["redirect"].str }, set: { put("redirect", .string($0)) }))
                        .keyboardType(.URL).textInputAutocapitalization(.never).environment(\.layoutDirection, .leftToRight)
                } else {
                    TextField("رسالة الحظر (عربي)", text: Binding(get: { g["message"]["ar"].str }, set: { var m = g["message"]; if !m.isObject { m = .i18n("") }; m["ar"] = .string($0); put("message", m) }), axis: .vertical).font(.ox(15))
                    TextField("Message (English)", text: Binding(get: { g["message"]["en"].str }, set: { var m = g["message"]; if !m.isObject { m = .i18n("") }; m["en"] = .string($0); put("message", m) }), axis: .vertical).font(.ox(14)).environment(\.layoutDirection, .leftToRight)
                }
                Toggle(isOn: Binding(get: { g["exemptAdmin"].bool ?? true }, set: { put("exemptAdmin", .bool($0)) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("اللوحة والتطبيق والملفات ما تنحظر").font(.ox(15))
                        Text("خلّيه شغّال حتى ما تقفل على نفسك").font(.ox(12)).foregroundStyle(t.mute)
                    }
                }
            } header: { Text("شنو يصير للمحظور") }

            if stats.loaded {
                Section {
                    InfoRow(title: "محاولات محظورة آخر 7 أيام", value: Fmt.n(stats.data["total"]), icon: "hand.raised.fill")
                    let bc = Array(stats.data["byCountry"].sortedCounts.prefix(10))
                    ForEach(bc.indices, id: \.self) { ci in let c = bc[ci]
                        BarRow(name: countryName(c.0), value: c.1, total: stats.data["total"].double ?? 1, max: stats.data["byCountry"].sortedCounts.first?.1 ?? 1, lead: flag(c.0))
                    }
                } header: { Text("الإحصائيات") }
            }
        }
        .formStyle(.grouped)
        .oxScreen("حظر الدول وIP", page: "geo")
        .task { await me.load(); await stats.load() }
        .refreshable { await stats.load() }
        .sheet(isPresented: $pickCountries) {
            CountryPicker(selected: Set(g["countries"].arr.map(\.str))) { set in
                put("countries", .array(set.sorted().map { .string($0) }))
            }
        }
    }

    func addIPs() async {
        let list = ipInput.split(whereSeparator: { ", \n;".contains($0) }).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !list.isEmpty else { return }
        do {
            let r = try await API.shared.post("/geo/check", ["ips": .array(list.map { .string($0) })])
            ipBad = r["bad"].arr.map(\.str)
            mineWarn = r["mine"].isTrue
            let good = list.filter { !ipBad.contains($0) }
            var a = g["ips"].arr
            for x in good where !a.contains(.string(x)) { a.append(.string(x)) }
            put("ips", .array(a))
            if ipBad.isEmpty { ipInput = "" }
        } catch { Toasts.shared.error(error) }
    }
}

struct CountryPicker: View {
    @State var selected: Set<String>
    var onDone: (Set<String>) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var q = ""
    static let all: [String] = Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 && Int($0) == nil }.sorted { countryName($0) < countryName($1) }
    static let quick = ["IQ", "SA", "AE", "KW", "JO", "SY", "LB", "TR", "IR", "EG", "US", "GB", "DE", "SE", "RU", "CN", "IN", "PK", "NG", "BR"]
    var body: some View {
        NavigationStack {
            List {
                if q.isEmpty {
                    Section("الأكثر زيارة للمنطقة") { ForEach(CountryPicker.quick, id: \.self) { row($0) } }
                }
                Section(q.isEmpty ? "كل الدول" : "النتائج") {
                    ForEach(CountryPicker.all.filter { q.isEmpty || countryName($0).contains(q) || $0.lowercased().contains(q.lowercased()) }, id: \.self) { row($0) }
                }
            }
            .searchable(text: $q, prompt: "ابحث باسم الدولة")
            .navigationTitle("اختر الدول").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("تم (\(Fmt.n(selected.count)))") { onDone(selected); dismiss() }.font(.ox(15, .semibold)) }
            }
        }
    }
    func row(_ cc: String) -> some View {
        Button {
            if selected.contains(cc) { selected.remove(cc) } else { selected.insert(cc) }
            Prefs.shared.tap()
        } label: {
            HStack {
                Text(flag(cc)).font(.system(size: 22))
                Text(countryName(cc)).font(.ox(15)).foregroundStyle(.primary)
                Spacer()
                if selected.contains(cc) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
            }
        }
    }
}
