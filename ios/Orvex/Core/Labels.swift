import Foundation

/// تسميات عربية لكل إعدادات الموقع + الخيارات + التلميحات
@MainActor
enum Labels {
    static let extra: [String: String] = [
        "visitors": "عدّاد المتصفحين", "texts": "النصوص المعدّلة والمخفية", "train": "وضع التدريب", "mood": "مزاج الوقت", "admins": "مشرفو بوت التيليجرام", "gate": "صندوق الحالة", "maintenance": "صفحة الصيانة", "offline": "صفحة الإيقاف", "over": "المعدّلة", "hide": "المخفية", "vip": "باقة VIP", "plans": "الباقات", "faq": "الأسئلة", "counters": "العدادات", "goals": "الأهداف", "steps": "خطوات المتابعة", "compare": "جدول المقارنة", "included": "ما تشمله الباقات", "gym": "القاعة", "gallery": "المعرض", "changelog": "تحديثات المنصة", "bar": "الشريط السفلي", "links": "الروابط", "developer": "كرت المطوّر", "legal": "الحقوق", "seo": "SEO", "ui": "المظهر", "currency": "العملة", "notify": "بوت الإشعارات", "pages": "الصفحات", "about": "من أنا", "privacy": "الخصوصية", "terms": "الشروط", "geo": "الحظر", "app": "التطبيق", "schedule": "الجدولة", "brand": "الهوية", "cta": "زر الدعوة",
        "enabled": "ظاهر بالموقع", "secondary": "الزر الثانوي", "place": "المكان", "priceNote": "ملاحظة السعر", "intro": "المقدمة", "value": "الرقم", "prefix": "رمز قبل الرقم", "vals": "قيم الباقات", "phone": "الهاتف", "directionsUrl": "رابط الاتجاهات", "mapsUrl": "رابط الخريطة", "placeId": "معرّف المكان بجوجل", "lat": "خط العرض", "lng": "خط الطول", "eta": "الموعد المتوقع", "showEta": "يعرض الموعد المتوقع", "code": "رمز الخطأ", "chips": "الشارات الصغيرة", "button": "بطاقة التدريب بالصفحة الرئيسية", "nutrition": "التغذية", "water": "الماء", "progress": "التقدّم", "tips": "النصائح", "backToPlans": "زر الرجوع للباقات",
        "palette": "تغيير الألوان حسب الوقت", "greet": "الترحيبة فوق الصفحة", "starts": "بداية كل فترة", "morning": "الصبح", "noon": "العصر", "evening": "المغرب", "night": "الليل", "list": "الترحيبات", "min": "أقل رقم يظهر للزائر", "usdRate": "سعر صرف الدولار (دينار)", "showBoth": "يعرض العملتين سوية", "welcome": "رسالة الترحيب", "already": "إذا كان مسجّل من قبل", "leftNote": "بعد ما ينشطب", "stranger": "لغير المسجلين", "openIntro": "مقدمة رسالة الفتح", "openMessage": "رسالة الفتح", "openCta": "نص رابط الاشتراك", "openFooter": "ذيل رسالة الفتح", "help": "شرح البوت", "statusIn": "حالته: مسجّل", "statusOut": "حالته: غير مسجّل", "joinLabel": "زر «ذكّرني»", "statusLabel": "زر «حالتي»", "leaveLabel": "زر «اشطبني»", "helpLabel": "زر الشرح", "igLabel": "زر إنستغرام", "short": "الوصف القصير", "botHandle": "معرّف البوت", "countText": "كلمة بجانب العدد", "showCount": "يعرض عدد المنتظرين", "email": "البريد", "whatsapp": "واتساب", "telegram": "تيليجرام", "join": "زر التسجيل", "status": "زر الحالة", "leave": "زر الشطب", "ar": "عربي", "en": "English", "on": "شغّال", "theme": "المظهر", "mode": "الوضع", "origin": "سطر البداية",
        "primary": "الزر الرئيسي", "closedNote": "ملاحظة وقت الإغلاق", "months": "عدد الأشهر", "featured": "مميّزة (الأكثر طلبًا)", "offer": "العرض والخصم", "features": "المزايا", "closing": "الجملة الختامية", "badge": "الشارة", "title": "العنوان", "duration": "المدة", "summary": "الوصف المختصر", "label": "النص", "kicker": "السطر الصغير فوق العنوان", "body": "النص", "note": "ملاحظة", "items": "العناصر", "rows": "الصفوف", "name": "الاسم", "icon": "الأيقونة", "caption": "التعليق", "tag": "الوسم", "before": "رابط صورة «قبل»", "after": "رابط صورة «بعد»", "q": "السؤال", "a": "الجواب", "n": "الرقم", "planId": "الباقة المعروضة بالشريط", "showLink": "يعرض رابط المعرض", "path": "رابط الصفحة", "lead": "المقدمة", "signature": "التوقيع",
        "countdown": "العدّاد التنازلي", "seats": "المقاعد", "remind": "زر التذكير", "reload": "زر إعادة التحميل", "profile": "ملف البوت", "buttons": "أزرار البوت", "labels": "تسميات العدّاد", "showUpdatedAt": "يعرض وقت آخر تحديث", "total": "عدد المقاعد الكلي", "taken": "المحجوز منها", "at": "الموعد", "endsAt": "ينتهي العرض", "oldPriceIQD": "السعر قبل الخصم (د.ع)", "oldPriceUSD": "السعر قبل الخصم ($)", "showPercent": "يعرض نسبة الخصم", "bonus": "هدية/مدة إضافية", "showEndsAt": "يعرض موعد انتهاء العرض", "headline": "عنوان العرض",
        "d": "الأيام", "h": "الساعات", "m": "الدقائق", "s": "الثواني", "allowOverride": "يسمح للزائر يغيّر الإعدادات", "showGrain": "ملمس الخلفية", "density": "التباعد", "motion": "الحركة", "accent": "اللون الأساسي", "lang": "اللغة الافتراضية", "instagramHandle": "معرّف إنستغرام", "site": "رابط الموقع", "siteLabel": "اسم الموقع", "avatar": "رابط الصورة", "line": "السطر", "version": "رقم الإصدار", "date": "التاريخ", "copyright": "حقوق النشر", "notice": "تنويه", "description": "الوصف", "ogImage": "صورة المشاركة", "tagline": "السطر التعريفي", "city": "المدينة", "address": "العنوان", "hours": "الدوام", "plusCode": "رمز الموقع", "priceIQD": "السعر (د.ع)", "priceUSD": "السعر ($)", "state": "الحالة", "text": "النص", "zeroText": "النص بعد ما يخلص العدّاد", "onZero": "لما يوصل الصفر", "style": "الشكل", "color": "اللون", "showDays": "يعرض الأيام", "showHours": "يعرض الساعات", "showMinutes": "يعرض الدقائق", "showSeconds": "يعرض الثواني", "showTargetDate": "يعرض تاريخ الموعد", "showDate": "يعرض التاريخ", "showLogo": "يعرض الشعار", "showInstagram": "يعرض زر إنستغرام", "auto": "تحديث تلقائي", "everySec": "كل كم ثانية", "url": "الرابط", "botUrl": "رابط البوت", "default": "العملة الافتراضية", "showState": "يعرض حالة الاشتراك", "showPrice": "يعرض السعر", "linkLabel": "نص الرابط", "linkNote": "سطر تحت الرابط", "subtitle": "السطر التحت العنوان",
        "openAt": "موعد الفتح", "closeAt": "موعد الإغلاق", "closedState": "الحالة بعد الإغلاق", "autoNotify": "يرسل التذكير تلقائيًا عند الفتح", "beforeState": "الحالة قبل الفتح", "countries": "الدول المحظورة", "ips": "عناوين IP المحظورة", "action": "الإجراء", "message": "الرسالة", "exemptAdmin": "اللوحة والتطبيق ما ينحظرون", "redirect": "رابط التحويل",
    ]
    static func label(_ key: String, _ p: [Seg] = []) -> String {
        if p.count >= 2, p[0].keyName == "gate", p[1].keyName == "cta", key == "label" { return "نص زر الاشتراك" }
        if p.count == 2, p[0].keyName == "gate", key == "text" { return "نص صندوق الحالة" }
        if p.count == 2, p[0].keyName == "gate", key == "note" { return "سطر إضافي تحت النص" }
        if p.first?.keyName == "changelog", key == "brand" { return "اسم المنصة" }
        if let e = extra[key] { return e }
        if let l = ConfigStore.shared.meta["labels"][key].string { return l.replacingOccurrences(of: "^[^\\p{Arabic}A-Za-z0-9«]+", with: "", options: .regularExpression) }
        return key
    }
    static func itemTitle(_ it: JSON, _ i: Int) -> String {
        if it.isI18n { let t = it.ar; return t.isEmpty ? "عنصر \(i + 1)" : t }
        guard it.isObject else { return it.str.isEmpty ? "عنصر \(i + 1)" : it.str }
        for k in ["title", "name", "q", "label", "text", "caption"] { let t = it[k].text; if !t.isEmpty {
            var s = t
            if it["priceIQD"].double != nil && k == "title" { s += " · " + Fmt.n(it["priceIQD"]) + " د.ع" }
            if let ic = it["icon"].string, k == "name" { s = ic + " " + s }
            if it["value"].double != nil && k == "label" { s = (it["prefix"].string ?? "") + Fmt.n(it["value"]) + " " + s }
            return s
        } }
        if let a = it["ar"].string, !a.isEmpty { return a }
        return "عنصر \(i + 1)"
    }
    static func pathLabel(_ p: [Seg], store: ConfigStore) -> String {
        var out: [String] = []
        for (i, s) in p.enumerated() {
            switch s {
            case .index(let n): out.append(String(itemTitle(store.draft.at(Array(p.prefix(i + 1))), n).prefix(24)))
            case .key(let k):
                if p.first?.keyName == "texts" && i == 2 { out.append(String((store.ui[k]["oar"].string ?? k).prefix(24))) }
                else { out.append(label(k, Array(p.prefix(i + 1)))) }
            }
        }
        return out.joined(separator: " › ")
    }
    static func describe(_ paths: [[Seg]], store: ConfigStore) -> String {
        let n = paths.prefix(3).map { pathLabel($0, store: store) }.joined(separator: "، ")
        return paths.count > 3 ? n + " و\(paths.count - 3) غيرها" : n
    }
    static func pattern(_ p: [Seg]) -> String { p.map { if case .index = $0 { return "*" }; return $0.description }.joined(separator: ".") }

    static func options(_ p: [Seg]) -> [(JSON, String)]? {
        let pt = pattern(p), m = ConfigStore.shared.meta
        func clean(_ s: String) -> String { s.replacingOccurrences(of: "^[^\\p{Arabic}]+", with: "", options: .regularExpression) }
        switch pt {
        case "gate.state": return m["gateStates"].object?.pairs.map { (JSON.string($0.0), clean($0.1.str)) }
        case "gate.countdown.style": return [("boxes", "صناديق"), ("inline", "سطر واحد"), ("minimal", "مختصر")]
        case "gate.countdown.onZero": return [("open", "يفتح الاشتراكات"), ("hide", "يختفي بهدوء"), ("message", "نص تكتبه"), ("keep", "يبقى على الصفر")]
        case "gate.schedule.closedState", "gate.schedule.beforeState": return [("closed", "مغلقة"), ("full", "اكتمل العدد"), ("soon", "تفتح قريبًا")]
        case "ui.theme": return [("dark", "داكن"), ("light", "فاتح")]
        case "ui.lang": return [("ar", "العربية"), ("en", "English")]
        case "ui.accent": return [("ember", "برتقالي"), ("brass", "نحاسي"), ("jade", "أخضر")]
        case "ui.density": return [("comfortable", "مريح"), ("compact", "مضغوط")]
        case "ui.motion": return [("full", "كاملة"), ("reduced", "مخففة")]
        case "visitors.mode": return [("now", "هسه"), ("hour", "آخر ساعة"), ("today", "اليوم")]
        case "currency.default": return [("IQD", "دينار"), ("USD", "دولار")]
        case "mood.mode": return [("daily", "ترحيبة لكل يوم"), ("random", "عشوائية")]
        case "mode": return [("live", "يشتغل"), ("maintenance", "صيانة"), ("offline", "موقوف")]
        case "geo.action": return [("block", "صفحة حظر"), ("redirect", "تحويل لرابط")]
        case "plans.*.offer.style": return m["offerStyles"].object?.pairs.map { (JSON.string($0.0), $0.1["n"].str) }
        case "plans.*.offer.color": return m["offerColors"].object?.pairs.map { (JSON.string($0.0), clean($0.1.str)) }
        case "bar.planId":
            let base: [(JSON, String)] = [(.string("auto"), "تلقائي"), (.string("none"), "بدون")]
            return base + ConfigStore.shared.draft["plans"].arr.map { (JSON.string($0["id"].str), $0["title"].text) }
        default:
            if pt.hasPrefix("mood.starts.") { return (0..<24).map { (JSON.number(Double($0)), String(format: "%02d:00", $0)) } }
            if pt.hasPrefix("mood.theme.") { return [("light", "فاتح"), ("dark", "غامق")] }
            return nil
        }
    }
    static let dateKeys: Set<String> = ["at", "endsAt", "eta", "openAt", "closeAt"]
    static let hiddenKeys: Set<String> = ["id", "offset", "notifiedFor"]
    static func isURL(_ k: String) -> Bool { k.range(of: "(url|Url|^site$|^instagram$|^whatsapp$|^telegram$|^about$|^privacy$|^terms$|^before$|^after$|^avatar$|^ogImage$|^redirect$)", options: .regularExpression) != nil }
    static func hint(_ p: [Seg]) -> String? {
        [
            "gate.countdown.at": "حسب توقيت جهازك", "plans.*.offer.endsAt": "اتركه فارغ إذا العرض بلا موعد", "currency.usdRate": "يستخدم لتحويل الأسعار",
            "visitors.min": "إذا العدد أقل من هذا ما يظهر للزائر", "gate.remind.botUrl": "رابط بوت الإشعارات", "offline.code": "الرقم الكبير بصفحة الإيقاف",
        ][pattern(p)]
    }

    static let sources = ["ig": "إنستغرام", "fb": "فيسبوك", "tg": "تيليجرام", "google": "جوجل", "tiktok": "تيك توك", "snap": "سناب", "wa": "واتساب", "direct": "مباشر", "internal": "من داخل الموقع", "other": "مواقع ثانية"]
    static let os = ["ios": "آيفون", "android": "أندرويد", "windows": "ويندوز", "mac": "ماك", "linux": "لينكس", "other": "غير ذلك"]
    static let browsers = ["instagram": "متصفح إنستغرام", "facebook": "متصفح فيسبوك", "tiktok": "تيك توك", "snapchat": "سناب", "telegram": "تيليجرام", "samsung": "سامسونج", "edge": "إيدج", "opera": "أوبرا", "firefox": "فايرفوكس", "chrome": "كروم", "safari": "سفاري", "other": "غير ذلك"]
    static let langs = ["ar": "العربية", "en": "الإنجليزية", "ku": "الكردية", "ckb": "الكردية", "tr": "التركية", "fa": "الفارسية", "de": "الألمانية", "sv": "السويدية", "fr": "الفرنسية", "xx": "غير معروفة"]
    static let devices = ["mob": "موبايل", "desk": "كمبيوتر", "tab": "تابلت"]
    static let pages = ["/": "الرئيسية", "/ar": "الرئيسية", "/en": "الرئيسية (إنجليزي)", "other": "صفحات ثانية"]
    static let events = ["cta": "ضغطات زر الاشتراك", "rem": "ضغطات «ذكّرني»", "train": "فتح وضع التدريب", "join": "تسجيل بالبوت", "leave": "شطب من البوت", "cast": "رسائل جماعية"]
    static let gateTone = ["open": "ok", "closed": "mute", "full": "warn", "soon": "info", "custom": "accent"]
}
