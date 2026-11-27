import SwiftUI

/// حظر الدول وعناوين IP
struct GeoView: View {
    @ObservedObject var store = ConfigStore.shared
    @StateObject private var stats = Remote("/geo/stats?days=7")
    @StateObject private var me = Remote("/geo/me")
    @State private var pickCountries = false
    @State private var ipInput = ""
    @State private var ipBad: [String] = []
    @State private var mineWarn = false

    static let defaults: JSON = ["enabled": false, "countries": [], "ips": [], "action": "block", "message": ["ar": "الموقع غير متاح في منطقتك.", "en": "This site isn't available in your region."], "redirect": "", "exemptAdmin": true]
    var g: JSON { store.v(P("geo")) }
    func put(_ k: String, _ v: JSON) {
        var n = g.isObject ? g : GeoView.defaults
        for (dk, dv) in GeoView.defaults.object!.pairs where n[dk].isNull { n[dk] = dv }
        n[k] = v
        store.set(P("geo"), n)
    }

    var body: some View {
        Page(title: "حظر الدول والعناوين", intro: "امنع الوصول إلى الموقع من دول أو عناوين IP محدّدة. لا يتأثر بوت التيليجرام بالحظر.", id: "geo") {
            Spacer().frame(height: 10)
            Card {
                ToggleRow(title: "تفعيل الحظر", sub: "\(Fmt.n(g["countries"].arr.count)) دولة و\(Fmt.n(g["ips"].arr.count)) عنوان", isOn: Binding(get: { g["enabled"].isTrue }, set: { put("enabled", .bool($0)) }))
                if me.loaded { InfoRow(title: "عنوانك الحالي", value: "\(flag(me.data["country"].str)) \(me.data["ip"].str)") }
            }
            if g["countries"].arr.contains(where: { $0.str == me.data["country"].str }) && g["exemptAdmin"].bool == false {
                Spacer().frame(height: 10)
                Note(text: "دولتك ضمن الدول المحظورة، ولوحة التحكم غير مستثناة. ستُحظر أنت أيضًا بعد الحفظ.", tone: "bad", icon: "exclamationmark.octagon.fill")
            }

            SectionTitle("الدول المحظورة")
            Card {
                ForEach(g["countries"].arr.map(\.str), id: \.self) { cc in
                    HStack(spacing: 12) {
                        Text(flag(cc)).font(.system(size: 24))
                        Text(countryName(cc)).font(.ox(15.5)).foregroundStyle(C.ink)
                        Spacer()
                        if let n = stats.data["byCountry"][cc].double, n > 0 { Text("\(Fmt.n(n)) محاولة").font(.ox(12)).foregroundStyle(C.mute) }
                        Button { put("countries", .array(g["countries"].arr.filter { $0.str != cc })) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(C.bad) }
                            .buttonStyle(.plain).accessibilityLabel("إزالة " + countryName(cc))
                    }.padding(.horizontal, 14).frame(minHeight: 52)
                }
                Button { pickCountries = true } label: {
                    Label("إضافة دولة", systemImage: "plus.circle.fill").font(.ox(15, .medium)).foregroundStyle(C.info)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(minHeight: 50)
                }.buttonStyle(.plain)
            }

            SectionTitle("عناوين IP المحظورة")
            Card {
                ForEach(Array(g["ips"].arr.enumerated()), id: \.offset) { i, ip in
                    HStack {
                        Text(ip.str).font(.system(size: 15, design: .monospaced)).foregroundStyle(C.ink).environment(\.layoutDirection, .leftToRight)
                        if ip.str.contains("/") { Pill(text: "نطاق") }
                        Spacer()
                        Button { var a = g["ips"].arr; a.remove(at: i); put("ips", .array(a)) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(C.bad) }.buttonStyle(.plain)
                    }.padding(.horizontal, 14).frame(minHeight: 50)
                }
                HStack(spacing: 10) {
                    TextField("مثل 1.2.3.4 أو 1.2.3.0/24", text: $ipInput)
                        .font(.system(size: 15, design: .monospaced)).keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).environment(\.layoutDirection, .leftToRight)
                        .onSubmit { Task { await addIPs() } }
                    Button("إضافة") { Task { await addIPs() } }.font(.ox(14.5, .semibold)).disabled(ipInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }.padding(.horizontal, 14).frame(minHeight: 52)
            }
            if !ipBad.isEmpty { SectionFooter("عناوين غير صالحة: " + ipBad.joined(separator: "، ")) }
            if mineWarn { Spacer().frame(height: 8); Note(text: "تشمل القائمة عنوانك الحالي.", tone: "warn", icon: "exclamationmark.triangle.fill") }
            SectionFooter("يمكنك لصق عدة عناوين مفصولة بفاصلة أو سطر جديد. يدعم IPv4 وIPv6 والنطاقات.")

            SectionTitle("ماذا يرى الزائر المحظور")
            Card {
                ChoiceRow(title: "الإجراء", options: [("block", "صفحة «غير متاح»"), ("redirect", "تحويله إلى رابط آخر")],
                          selection: Binding(get: { g["action"].string ?? "block" }, set: { put("action", .string($0)) }))
                if g["action"].string == "redirect" {
                    TextBlock(title: "رابط التحويل", placeholder: "https://", text: Binding(get: { g["redirect"].str }, set: { put("redirect", .string($0)) }), ltr: true, keyboard: .URL)
                } else {
                    TextBlock(title: "الرسالة بالعربية", text: Binding(get: { g["message"]["ar"].str }, set: { var m = g["message"]; if !m.isObject { m = .i18n("") }; m["ar"] = .string($0); put("message", m) }), multiline: true)
                    TextBlock(title: "الرسالة بالإنجليزية", text: Binding(get: { g["message"]["en"].str }, set: { var m = g["message"]; if !m.isObject { m = .i18n("") }; m["en"] = .string($0); put("message", m) }), ltr: true, multiline: true)
                }
                ToggleRow(title: "استثناء لوحة التحكم والتطبيق والملفات", sub: "أبقِه مفعّلًا حتى لا تمنع نفسك من الدخول", isOn: Binding(get: { g["exemptAdmin"].bool ?? true }, set: { put("exemptAdmin", .bool($0)) }))
            }

            if stats.loaded && (stats.data["total"].double ?? 0) > 0 {
                SectionTitle("المحاولات المحظورة خلال 7 أيام", trailing: Fmt.n(stats.data["total"]))
                Card {
                    let bc = stats.data["byCountry"].counts
                    ForEach(Array(bc.prefix(8).enumerated()), id: \.offset) { _, c in
                        BarRow(name: countryName(c.key), value: c.n, total: stats.data["total"].double ?? 1, max: bc.first?.n ?? 1, lead: flag(c.key))
                    }
                }
            }
        }
        .task { await me.load(); await stats.load() }
        .sheet(isPresented: $pickCountries) {
            CountryPicker(selected: Set(g["countries"].arr.map(\.str))) { set in put("countries", .array(set.sorted().map { .string($0) })) }
        }
    }

    func addIPs() async {
        let list = ipInput.split(whereSeparator: { ", \n;".contains($0) }).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !list.isEmpty else { return }
        do {
            let r = try await API.shared.post("/geo/check", ["ips": .array(list.map { .string($0) })])
            ipBad = r["bad"].arr.map(\.str); mineWarn = r["mine"].isTrue
            var a = g["ips"].arr
            for x in list where !ipBad.contains(x) && !a.contains(.string(x)) { a.append(.string(x)) }
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
    static let common = ["IQ", "SA", "AE", "KW", "JO", "SY", "LB", "TR", "IR", "EG", "US", "GB", "DE", "SE", "RU", "CN", "IN", "PK"]
    var body: some View {
        NavigationStack {
            List {
                if q.isEmpty { Section("الأكثر شيوعًا") { ForEach(CountryPicker.common, id: \.self) { row($0) } } }
                Section(q.isEmpty ? "كل الدول" : "النتائج") {
                    ForEach(CountryPicker.all.filter { q.isEmpty || countryName($0).contains(q) || $0.lowercased().contains(q.lowercased()) }, id: \.self) { row($0) }
                }
            }
            .searchable(text: $q, prompt: "ابحث باسم الدولة")
            .navigationTitle("اختيار الدول").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("تم") { onDone(selected); dismiss() }.font(.ox(15, .semibold)) }
            }
        }
    }
    func row(_ cc: String) -> some View {
        Button {
            if selected.contains(cc) { selected.remove(cc) } else { selected.insert(cc) }
            Haptics.tap()
        } label: {
            HStack {
                Text(flag(cc)).font(.system(size: 22))
                Text(countryName(cc)).font(.ox(15)).foregroundStyle(C.ink)
                Spacer()
                if selected.contains(cc) { Image(systemName: "checkmark.circle.fill").foregroundStyle(C.info) }
            }
        }
    }
}
