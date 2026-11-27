import SwiftUI

/// تعريف كل نماذج تحرير الموقع وقوائمه بعناوين عربية واضحة
@MainActor
enum Defs {
    typealias F = Field
    static let gateStates: [(String, String)] = [("open", "مفتوحة"), ("soon", "تُفتح قريبًا"), ("full", "اكتمل العدد"), ("closed", "مغلقة"), ("custom", "نص مخصّص")]

    // MARK: النماذج
    static let forms: [String: FormDef] = {
        var d: [String: FormDef] = [:]
        func add(_ f: FormDef) { d[f.id] = f }

        // —— الاشتراكات
        add(FormDef(id: "gate-extra", title: "أزرار صندوق الاشتراك", intro: "العناصر التي تظهر أسفل نص حالة الاشتراكات في الموقع.", sections: [
            FormSection("سطر إضافي", footer: "يظهر بخط أصغر تحت نص الحالة. اتركه فارغًا لإخفائه.", [
                F("note", "السطر الإضافي", .long),
                F("showUpdatedAt", "إظهار وقت آخر تحديث للحالة", .toggle),
            ]),
            FormSection("زر الاشتراك", [
                F("cta.enabled", "إظهار زر الاشتراك", .toggle),
                F("cta.label", "نص الزر"),
                F("cta.url", "الرابط الذي يفتحه الزر", .url),
            ]),
            FormSection("زر «ذكّرني عند الفتح»", footer: "يظهر عندما تكون الاشتراكات غير مفتوحة، ويسجّل الزائر في قائمة المنتظرين.", [
                F("remind.enabled", "إظهار زر التذكير", .toggle),
                F("remind.label", "نص الزر"),
                F("remind.note", "الشرح تحت الزر", .long),
                F("remind.showCount", "إظهار عدد المنتظرين", .toggle),
                F("remind.countText", "الكلمة بجانب العدد", placeholder: "شخص بانتظار الفتح"),
            ]),
            FormSection("المقاعد المتبقية", [
                F("seats.enabled", "إظهار عدد المقاعد المتبقية", .toggle),
                F("seats.total", "إجمالي المقاعد", .number(nil)),
                F("seats.taken", "المقاعد المحجوزة", .number(nil)),
            ]),
            FormSection("العدّاد التنازلي", footer: "عدّاد يدوي يظهر في صندوق الاشتراك. للفتح التلقائي في موعد محدّد استخدم «جدولة الفتح والإغلاق».", [
                F("countdown.enabled", "إظهار العدّاد", .toggle),
                F("countdown.at", "موعد انتهاء العدّاد", .date),
                F("countdown.title", "العنوان فوق العدّاد"),
                F("countdown.onZero", "عند وصول العدّاد إلى الصفر", .choice([("open", "تُفتح الاشتراكات"), ("hide", "يختفي العدّاد"), ("message", "يظهر نص مخصّص"), ("keep", "يبقى على الصفر")])),
                F("countdown.zeroText", "النص بعد انتهاء العدّاد"),
            ]),
        ]))

        add(FormDef(id: "plan", title: "تفاصيل الباقة", intro: "كل ما يظهر في بطاقة هذه الباقة.", sections: [
            FormSection("الأساسيات", [
                F("enabled", "الباقة ظاهرة في الموقع", .toggle),
                F("title", "اسم الباقة", placeholder: "اشتراك 3 أشهر"),
                F("duration", "المدة كما تظهر للزائر", placeholder: "90 يوم متابعة"),
                F("months", "عدد الأشهر", .number("شهر")),
                F("featured", "إبرازها كالباقة الأكثر طلبًا", .toggle),
                F("badge", "الشارة فوق الباقة", placeholder: "الأكثر طلبًا"),
            ]),
            FormSection("السعر", [
                F("priceIQD", "السعر بالدينار", .money("IQD")),
                F("priceUSD", "السعر بالدولار", .money("USD")),
            ]),
            FormSection("الوصف", [
                F("summary", "الوصف المختصر", .long),
                F("closing", "الجملة الختامية", .long),
            ]),
        ], links: [FormLink(title: "العرض والخصم", sub: "شارة العرض والسعر قبل الخصم", icon: "percent", color: "orange") { .form("plan-offer", $0 + [.key("offer")]) }],
           lines: [("المزايا", "features", "إضافة ميزة")]))

        add(FormDef(id: "plan-offer", title: "العرض والخصم", intro: "يظهر على بطاقة الباقة عند تفعيله.", sections: [
            FormSection(nil, [F("enabled", "تفعيل العرض", .toggle)]),
            FormSection("شكل العرض", showIf: "enabled", [
                F("style", "طريقة العرض", .choice([("ribbon", "شريط مائل"), ("banner", "لافتة داخلية"), ("corner", "بطاقة في الزاوية"), ("glow", "توهّج حول البطاقة")])),
                F("color", "اللون", .choice([("ember", "برتقالي"), ("brass", "نحاسي"), ("jade", "أخضر"), ("ocean", "أزرق"), ("violet", "بنفسجي")])),
                F("badge", "نص الشارة", placeholder: "عرض خاص"),
                F("headline", "عنوان العرض"),
                F("note", "تفاصيل العرض", .long),
                F("bonus", "هدية أو مدة إضافية"),
            ]),
            FormSection("السعر قبل الخصم", footer: "يظهر مشطوبًا بجانب السعر الحالي. اتركه صفرًا لإخفائه.", showIf: "enabled", [
                F("oldPriceIQD", "السعر السابق بالدينار", .money("IQD")),
                F("oldPriceUSD", "السعر السابق بالدولار", .money("USD")),
                F("showPercent", "إظهار نسبة الخصم", .toggle),
            ]),
            FormSection("مدة العرض", showIf: "enabled", [
                F("endsAt", "موعد انتهاء العرض", .date),
                F("showEndsAt", "إظهار موعد الانتهاء للزائر", .toggle),
            ]),
        ]))

        add(FormDef(id: "vip", title: "باقة VIP", intro: "باقة التدريب الشخصي داخل القاعة.", sections: [
            FormSection("الأساسيات", [
                F("enabled", "الباقة ظاهرة في الموقع", .toggle),
                F("label", "الشارة", placeholder: "باقة النخبة"),
                F("title", "العنوان"),
                F("place", "المكان"),
            ]),
            FormSection("السعر", footer: "اترك السعر صفرًا إذا كان يُحدَّد حسب الطلب، واكتب ذلك في ملاحظة السعر.", [
                F("priceIQD", "السعر بالدينار", .money("IQD")),
                F("priceUSD", "السعر بالدولار", .money("USD")),
                F("priceNote", "ملاحظة السعر"),
            ]),
            FormSection("الوصف", [F("intro", "المقدمة", .long), F("closing", "الجملة الختامية", .long)]),
        ], lines: [("المزايا", "features", "إضافة ميزة")]))

        add(FormDef(id: "pricing", title: "العملة وشريط الاشتراك", intro: "طريقة عرض الأسعار، والشريط الثابت أسفل الصفحة.", sections: [
            FormSection("العملة", [
                F("currency.default", "العملة الافتراضية", .choice([("IQD", "الدينار العراقي"), ("USD", "الدولار الأمريكي")])),
                F("currency.showBoth", "إظهار العملتين معًا", .toggle),
                F("currency.usdRate", "سعر صرف الدولار", .number("د.ع"), help: "يُستخدم لحساب السعر عند عدم إدخاله بالدولار."),
            ]),
            FormSection("شريط الاشتراك السفلي", footer: "شريط صغير يبقى ظاهرًا أسفل الشاشة أثناء التصفّح.", [
                F("bar.enabled", "إظهار الشريط", .toggle),
                F("bar.label", "نص الزر"),
                F("bar.planId", "الباقة المعروضة", .dynamicChoice({
                    [("auto", "تلقائيًا (الأكثر طلبًا)"), ("none", "بدون باقة")] + ConfigStore.shared.draft["plans"].arr.map { ($0["id"].str, $0["title"].text) }
                })),
                F("bar.showState", "إظهار حالة الاشتراكات", .toggle),
                F("bar.showPrice", "إظهار السعر", .toggle),
            ]),
        ]))

        // —— المحتوى
        add(FormDef(id: "intro", title: "التعريف والأزرار", intro: "أول ما يراه الزائر في أعلى الصفحة الرئيسية.", sections: [
            FormSection("التعريف", [
                F("brand.name", "الاسم"),
                F("brand.kicker", "السطر الصغير فوق الاسم", placeholder: "مدرب لياقة بدنية معتمد"),
                F("brand.tagline", "النبذة", .long),
            ]),
            FormSection("الأزرار", [
                F("cta.primary", "نص الزر الرئيسي"),
                F("cta.secondary", "نص الزر الثانوي"),
                F("cta.closedNote", "ملاحظة عند إغلاق الاشتراكات", .long),
            ]),
        ]))
        add(FormDef(id: "included", title: "ما تشمله الباقات", sections: [
            FormSection(nil, [F("enabled", "القسم ظاهر في الموقع", .toggle)]),
            FormSection("النص", [F("title", "العنوان"), F("body", "النص", .long), F("signature", "التوقيع")]),
        ]))
        add(FormDef(id: "counter", title: "رقم", sections: [
            FormSection(nil, [
                F("enabled", "ظاهر في الموقع", .toggle),
                F("value", "الرقم", .number(nil)),
                F("prefix", "رمز قبل الرقم", .plain, placeholder: "+"),
                F("label", "الوصف", placeholder: "متدرب"),
            ]),
        ]))
        add(FormDef(id: "goals", title: "قسم «اختر هدفك»", sections: [
            FormSection(nil, [F("enabled", "القسم ظاهر في الموقع", .toggle)]),
            FormSection("العنوان", [F("title", "العنوان"), F("subtitle", "السطر التعريفي", .long)]),
        ], links: [FormLink(title: "الأهداف", sub: "إضافة الأهداف وتعديلها", icon: "target", color: "red") { .list("goal-items", $0 + [.key("items")]) }]))
        add(FormDef(id: "goal", title: "هدف", sections: [
            FormSection(nil, [F("icon", "الرمز التعبيري", .plain, placeholder: "🔥"), F("name", "اسم الهدف"), F("body", "الوصف", .long)]),
        ]))
        add(FormDef(id: "steps", title: "قسم «خطوات المتابعة»", sections: [
            FormSection(nil, [F("enabled", "القسم ظاهر في الموقع", .toggle)]),
            FormSection("العنوان", [F("title", "العنوان"), F("subtitle", "السطر التعريفي", .long)]),
        ], links: [FormLink(title: "الخطوات", sub: "الخطوات بالترتيب", icon: "list.number", color: "blue") { .list("step-items", $0 + [.key("items")]) }]))
        add(FormDef(id: "step", title: "خطوة", sections: [
            FormSection(nil, [F("n", "رقم الخطوة", .plain, placeholder: "01"), F("name", "عنوان الخطوة"), F("body", "الشرح", .long)]),
        ]))
        add(FormDef(id: "compare", title: "جدول المقارنة", sections: [
            FormSection(nil, [F("enabled", "القسم ظاهر في الموقع", .toggle)]),
            FormSection("العنوان", [F("title", "العنوان"), F("subtitle", "السطر التعريفي", .long)]),
        ], links: [FormLink(title: "صفوف الجدول", sub: "كل صف يقارن الباقات في نقطة واحدة", icon: "tablecells", color: "indigo") { .list("compare-rows", $0 + [.key("rows")]) }]))
        add(FormDef(id: "compare-row", title: "صف في الجدول", sections: [
            FormSection(nil, [F("label", "اسم الصف", placeholder: "مدة المتابعة")]),
        ], lines: [("القيمة لكل باقة بالترتيب", "vals", "إضافة قيمة")]))
        add(FormDef(id: "faq-item", title: "سؤال", sections: [
            FormSection(nil, [F("enabled", "ظاهر في الموقع", .toggle), F("q", "السؤال", .long), F("a", "الجواب", .long)]),
        ]))
        add(FormDef(id: "gym", title: "القاعة والموقع", intro: "معلومات قاعة التدريب والخريطة.", sections: [
            FormSection(nil, [F("enabled", "القسم ظاهر في الموقع", .toggle)]),
            FormSection("المعلومات", [F("name", "اسم القاعة"), F("city", "المدينة"), F("address", "العنوان"), F("hours", "أوقات الدوام"), F("note", "ملاحظة", .long)]),
            FormSection("الخريطة", [F("mapsUrl", "رابط الخريطة", .url), F("directionsUrl", "رابط الاتجاهات", .url)]),
        ]))
        add(FormDef(id: "train", title: "وضع التدريب", intro: "بطاقة المدرّب الذكي في الصفحة الرئيسية وصفحته.", sections: [
            FormSection(nil, [F("enabled", "وضع التدريب متاح", .toggle), F("button", "إظهار بطاقته في الصفحة الرئيسية", .toggle)]),
            FormSection("البطاقة", [F("kicker", "السطر الصغير"), F("title", "العنوان"), F("body", "الوصف", .long), F("cta", "نص الزر")]),
            FormSection("أقسام وضع التدريب", [
                F("app.nutrition", "التغذية", .toggle), F("app.water", "شرب الماء", .toggle), F("app.progress", "متابعة التقدّم", .toggle),
                F("app.tips", "النصائح", .toggle), F("app.backToPlans", "زر العودة إلى الباقات", .toggle),
            ]),
        ], lines: [("الشارات الصغيرة", "chips", "إضافة شارة")]))
        add(FormDef(id: "changelog", title: "تحديثات المنصة", intro: "بطاقة «آخر تحديث للمنصة» أسفل الصفحة.", sections: [
            FormSection(nil, [F("enabled", "القسم ظاهر في الموقع", .toggle)]),
            FormSection("الإصدار", [F("brand", "اسم المنصة", .plain), F("version", "رقم الإصدار", .plain), F("label", "العنوان"), F("date", "التاريخ")]),
            FormSection("البداية", [F("origin.enabled", "إظهار سطر البداية", .toggle), F("origin.label", "العنوان"), F("origin.date", "التاريخ"), F("origin.text", "النص", .long)]),
        ], links: [FormLink(title: "بنود التحديث", icon: "sparkles", color: "purple") { .list("changelog-items", $0 + [.key("items")]) }]))
        add(FormDef(id: "changelog-item", title: "بند", sections: [FormSection(nil, [F("enabled", "ظاهر", .toggle), F("text", "النص")])]))
        add(FormDef(id: "gallery", title: "معرض النتائج", intro: "صفحة صور «قبل وبعد» للمتدربين.", sections: [
            FormSection(nil, [F("enabled", "المعرض متاح", .toggle), F("showLink", "إظهار رابطه في الصفحة الرئيسية", .toggle)]),
            FormSection("الرابط في الصفحة الرئيسية", [F("linkLabel", "نص الرابط"), F("linkNote", "السطر تحت الرابط")]),
            FormSection("صفحة المعرض", [F("title", "العنوان"), F("subtitle", "السطر التعريفي", .long), F("note", "ملاحظة أسفل الصفحة", .long), F("beforeLabel", "كلمة «قبل»"), F("afterLabel", "كلمة «بعد»")]),
        ], links: [FormLink(title: "الصور", sub: "صور قبل وبعد", icon: "photo.on.rectangle", color: "pink") { .list("gallery-items", $0 + [.key("items")]) }]))
        add(FormDef(id: "gallery-item", title: "صورة", intro: "ارفع الصورتين من «الملفات» ثم الصق رابطيهما هنا.", sections: [
            FormSection(nil, [F("enabled", "ظاهرة في المعرض", .toggle), F("before", "رابط صورة «قبل»", .url), F("after", "رابط صورة «بعد»", .url), F("caption", "التعليق"), F("tag", "الوسم", placeholder: "3 أشهر")]),
        ]))
        for (k, t) in [("about", "صفحة «من أنا»"), ("terms", "صفحة الشروط"), ("privacy", "صفحة الخصوصية")] {
            add(FormDef(id: "page-" + k, title: t, sections: [
                FormSection(nil, [F("enabled", "الصفحة متاحة", .toggle)]),
                FormSection("المحتوى", footer: "افصل بين الفقرات بسطر فارغ.", [F("title", "العنوان"), F("lead", "المقدمة", .long), F("body", "النص", .long), F("signature", "التوقيع")]),
            ]))
        }
        add(FormDef(id: "links", title: "الروابط والتواصل", intro: "الروابط التي تستخدمها أزرار الموقع.", bilingual: false, sections: [
            FormSection("التواصل", [
                F("links.instagram", "رابط إنستغرام", .url), F("links.instagramHandle", "معرّف إنستغرام", .plain, placeholder: "@iraq__fit8"),
                F("links.whatsapp", "رابط واتساب", .url), F("links.telegram", "رابط تيليجرام", .url), F("links.email", "البريد الإلكتروني", .plain),
            ]),
            FormSection("الموقع", [F("links.site", "رابط الموقع", .url)]),
        ]))
        add(FormDef(id: "seo", title: "محركات البحث والحقوق", intro: "عنوان الموقع ووصفه في Google وعند مشاركة الرابط.", sections: [
            FormSection("محركات البحث", [F("seo.title", "عنوان الموقع"), F("seo.description", "الوصف", .long), F("seo.ogImage", "صورة المشاركة", .url)]),
            FormSection("الحقوق", [F("legal.copyright", "سطر حقوق النشر"), F("legal.notice", "التنويه", .long)]),
        ]))
        add(FormDef(id: "developer", title: "بطاقة المطوّر", bilingual: false, sections: [
            FormSection(nil, [F("enabled", "البطاقة ظاهرة في الموقع", .toggle)]),
            FormSection("المحتوى", [F("line", "السطر الأول", .text), F("name", "الاسم", .plain), F("site", "رابط الموقع", .url), F("siteLabel", "اسم الموقع", .plain), F("instagram", "رابط إنستغرام", .url), F("instagramHandle", "معرّف إنستغرام", .plain)]),
        ]))
        add(FormDef(id: "visitors", title: "عدّاد المتصفحين", intro: "الرقم الصغير الذي يبيّن للزائر عدد المتصفحين.", bilingual: false, sections: [
            FormSection(nil, [
                F("enabled", "إظهار العدّاد في الموقع", .toggle),
                F("mode", "ماذا يعرض", .choice([("now", "المتصفحون الآن"), ("hour", "زوار آخر ساعة"), ("today", "زوار اليوم")])),
                F("min", "أقل عدد يظهر فيه العدّاد", .number(nil), help: "إذا كان العدد أقل من هذا الرقم يختفي العدّاد."),
            ]),
        ]))
        add(FormDef(id: "look", title: "المظهر الافتراضي للزوار", intro: "شكل الموقع عند أول زيارة. يستطيع الزائر تغييره إن سمحت بذلك.", bilingual: false, sections: [
            FormSection(nil, [
                F("ui.theme", "الوضع", .choice([("dark", "داكن"), ("light", "فاتح")])),
                F("ui.accent", "اللون الأساسي", .choice([("ember", "برتقالي"), ("brass", "نحاسي"), ("jade", "أخضر")])),
                F("ui.lang", "اللغة", .choice([("ar", "العربية"), ("en", "الإنجليزية")])),
                F("ui.density", "التباعد", .choice([("comfortable", "مريح"), ("compact", "مضغوط")])),
                F("ui.motion", "الحركة", .choice([("full", "كاملة"), ("reduced", "مخفّفة")])),
                F("ui.showGrain", "ملمس الخلفية", .toggle),
                F("ui.allowOverride", "السماح للزائر بتغيير المظهر", .toggle),
            ]),
        ]))
        add(FormDef(id: "mood", title: "الترحيب والألوان حسب الوقت", intro: "يتغيّر لون الموقع وعبارة الترحيب حسب وقت الزيارة بتوقيت بغداد.", bilingual: false, sections: [
            FormSection(nil, [
                F("mood.enabled", "تفعيل الميزة", .toggle),
                F("mood.palette", "تغيير الألوان حسب الوقت", .toggle),
                F("mood.greet", "إظهار عبارة الترحيب", .toggle),
                F("mood.mode", "طريقة اختيار العبارة", .choice([("daily", "عبارة واحدة لكل يوم"), ("random", "عبارة عشوائية في كل زيارة")])),
            ]),
            FormSection("بداية كل فترة", footer: "الساعة بنظام 24 ساعة.", [
                F("mood.starts.morning", "الصباح", .number(":00")), F("mood.starts.noon", "الظهيرة", .number(":00")),
                F("mood.starts.evening", "المساء", .number(":00")), F("mood.starts.night", "الليل", .number(":00")),
            ]),
        ], links: [
            FormLink(title: "عبارات الصباح", icon: "sunrise.fill", color: "amber") { _ in .list("mood-list", P("mood", "list", "morning")) },
            FormLink(title: "عبارات الظهيرة", icon: "sun.max.fill", color: "orange") { _ in .list("mood-list", P("mood", "list", "noon")) },
            FormLink(title: "عبارات المساء", icon: "sunset.fill", color: "pink") { _ in .list("mood-list", P("mood", "list", "evening")) },
            FormLink(title: "عبارات الليل", icon: "moon.stars.fill", color: "indigo") { _ in .list("mood-list", P("mood", "list", "night")) },
        ]))
        add(FormDef(id: "mood-item", title: "عبارة ترحيب", bilingual: false, sections: [
            FormSection(nil, [F("on", "مفعّلة", .toggle), F("ar", "بالعربية", .plain), F("en", "بالإنجليزية", .plain)]),
        ]))
        // —— التشغيل
        add(FormDef(id: "maintenance", title: "صفحة الصيانة", intro: "ما يراه الزائر عندما يكون الموقع في وضع الصيانة.", sections: [
            FormSection("النص", [F("kicker", "السطر الصغير"), F("title", "العنوان"), F("body", "النص", .long)]),
            FormSection("العناصر", [F("showLogo", "إظهار الشعار", .toggle), F("showInstagram", "إظهار زر إنستغرام", .toggle)]),
            FormSection("عدّاد العودة", [F("countdown.enabled", "إظهار عدّاد حتى انتهاء الصيانة", .toggle), F("countdown.at", "موعد انتهاء الصيانة", .date), F("countdown.title", "العنوان فوق العدّاد"), F("countdown.zeroText", "النص بعد انتهاء العدّاد")]),
            FormSection("إعادة التحميل", [F("reload.enabled", "إظهار زر إعادة التحميل", .toggle), F("reload.label", "نص الزر"), F("reload.auto", "إعادة التحميل تلقائيًا", .toggle), F("reload.everySec", "كل", .number("ثانية"))]),
        ]))
        add(FormDef(id: "offline", title: "صفحة الإيقاف", intro: "ما يراه الزائر عندما يكون الموقع متوقفًا.", sections: [
            FormSection("النص", [F("code", "رمز الخطأ", .plain, placeholder: "404"), F("kicker", "السطر الصغير"), F("title", "العنوان"), F("body", "النص", .long)]),
            FormSection("العناصر", [F("showLogo", "إظهار الشعار", .toggle), F("showInstagram", "إظهار زر إنستغرام", .toggle)]),
            FormSection("إعادة التحميل", [F("reload.enabled", "إظهار زر إعادة التحميل", .toggle), F("reload.label", "نص الزر"), F("reload.auto", "إعادة التحميل تلقائيًا", .toggle), F("reload.everySec", "كل", .number("ثانية"))]),
        ]))
        // —— بوت التذكير
        add(FormDef(id: "bot", title: "رسائل بوت التذكير", intro: "الرسائل التي يرسلها بوت التيليجرام للمنتظرين. يمكن استخدام <b>عريض</b> و<i>مائل</i>.", sections: [
            FormSection("رسالة الفتح", footer: "تُرسل لكل المنتظرين عند فتح الاشتراكات.", [F("openIntro", "المقدمة"), F("openMessage", "الرسالة", .long), F("openCta", "نص رابط الاشتراك"), F("openFooter", "التذييل", .long)]),
            FormSection("رسائل التسجيل", [F("welcome", "عند التسجيل", .long), F("already", "إذا كان مسجّلًا من قبل", .long), F("leftNote", "عند إلغاء التسجيل", .long), F("statusIn", "حالته: مسجّل", .long), F("statusOut", "حالته: غير مسجّل", .long), F("stranger", "لمن يراسل البوت دون تسجيل", .long), F("help", "شرح البوت", .long)]),
            FormSection("أزرار البوت", [F("joinLabel", "زر التسجيل"), F("statusLabel", "زر الحالة"), F("leaveLabel", "زر إلغاء التسجيل"), F("helpLabel", "زر الشرح"), F("igLabel", "زر إنستغرام"), F("siteLabel", "زر الموقع")]),
            FormSection("ملف البوت", [F("profile.short", "الوصف القصير"), F("profile.description", "الوصف الكامل", .long)]),
        ]))
        return d
    }()

    // MARK: القوائم
    static let lists: [String: ListDef] = {
        var d: [String: ListDef] = [:]
        func add(_ l: ListDef) { d[l.id] = l }
        func i18n(_ k: String) -> (JSON) -> String { { $0[k].text } }
        add(ListDef(id: "plans", title: "الباقات والأسعار", intro: "رتّب الباقات كما تريد ظهورها في الموقع.", itemForm: "plan", addLabel: "إضافة باقة",
                    template: ["id": "p", "months": 1, "enabled": false, "featured": false, "badge": .i18n(""), "title": .i18n("باقة جديدة", "New plan"), "duration": .i18n(""), "priceIQD": 0, "priceUSD": 0, "summary": .i18n(""), "features": [], "closing": .i18n(""),
                               "offer": ["enabled": false, "style": "ribbon", "color": "ember", "badge": .i18n("عرض خاص", "Special offer"), "headline": .i18n(""), "note": .i18n(""), "oldPriceIQD": 0, "oldPriceUSD": 0, "showPercent": true, "bonus": .i18n(""), "endsAt": nil, "showEndsAt": false]],
                    itemTitle: { $0["title"].text },
                    itemSub: { p in (p["priceIQD"].double ?? 0) > 0 ? Fmt.money(p["priceIQD"].double) + " · " + Fmt.money(p["priceUSD"].double, "USD") + (p["offer"]["enabled"].isTrue ? " · عليها عرض" : "") : nil }))
        add(ListDef(id: "counters", title: "الأرقام", intro: "الأرقام البارزة أعلى الصفحة الرئيسية.", itemForm: "counter", addLabel: "إضافة رقم",
                    template: ["id": "c", "enabled": true, "value": 0, "prefix": "+", "label": .i18n("")],
                    itemTitle: { ($0["prefix"].string ?? "") + Fmt.n($0["value"]) + " " + $0["label"].text }))
        add(ListDef(id: "goal-items", title: "الأهداف", itemForm: "goal", addLabel: "إضافة هدف", template: ["id": "g", "icon": "🎯", "name": .i18n(""), "body": .i18n("")],
                    itemTitle: { ($0["icon"].string ?? "") + " " + $0["name"].text }, itemSub: { $0["body"].text }, enabledKey: nil))
        add(ListDef(id: "step-items", title: "الخطوات", itemForm: "step", addLabel: "إضافة خطوة", template: ["id": "s", "n": "", "name": .i18n(""), "body": .i18n("")],
                    itemTitle: { ($0["n"].string.map { $0 + "  " } ?? "") + $0["name"].text }, itemSub: { $0["body"].text }, enabledKey: nil))
        add(ListDef(id: "compare-rows", title: "صفوف الجدول", itemForm: "compare-row", addLabel: "إضافة صف", template: ["id": "r", "label": .i18n(""), "vals": [.i18n(""), .i18n(""), .i18n("")]],
                    itemTitle: { $0["label"].text }, itemSub: { $0["vals"].arr.map(\.text).joined(separator: " · ") }, enabledKey: nil))
        add(ListDef(id: "faq", title: "الأسئلة الشائعة", intro: "رتّب الأسئلة كما تريد ظهورها.", itemForm: "faq-item", addLabel: "إضافة سؤال", template: ["id": "f", "enabled": true, "q": .i18n(""), "a": .i18n("")],
                    itemTitle: { $0["q"].text }, itemSub: { $0["a"].text }))
        add(ListDef(id: "changelog-items", title: "بنود التحديث", itemForm: "changelog-item", addLabel: "إضافة بند", template: ["id": "c", "enabled": true, "text": .i18n("")], itemTitle: i18n("text")))
        add(ListDef(id: "gallery-items", title: "صور المعرض", itemForm: "gallery-item", addLabel: "إضافة صورة", template: ["id": "g", "enabled": false, "before": "", "after": "", "caption": .i18n(""), "tag": .i18n("")],
                    itemTitle: { $0["caption"].text.isEmpty ? "صورة بلا تعليق" : $0["caption"].text }, itemSub: { $0["before"].str.isEmpty || $0["after"].str.isEmpty ? "ينقصها رابط صورة" : $0["tag"].text }))
        add(ListDef(id: "mood-list", title: "عبارات الترحيب", intro: "تظهر عبارة واحدة منها أعلى الموقع في هذه الفترة.", itemForm: "mood-item", addLabel: "إضافة عبارة", template: ["id": "m", "ar": "", "en": "", "on": true],
                    itemTitle: { $0["ar"].str }, itemSub: { $0["en"].str }, enabledKey: "on"))
        return d
    }()

    static func form(_ id: String) -> FormDef { forms[id] ?? FormDef(id: id, title: "غير متاح", sections: []) }
    static func list(_ id: String) -> ListDef { lists[id] ?? ListDef(id: id, title: "غير متاح", itemForm: "", addLabel: "", template: .null, itemTitle: { _ in "" }) }
}

// MARK: - أسماء الحقول لوصف التعديلات في سجل التعديلات وشريط الحفظ
@MainActor
enum FieldNames {
    /// أين يقع كل نموذج داخل الإعدادات
    static let bases: [(String, String)] = [
        ("gate", "gate-extra"), ("plans.*", "plan"), ("plans.*.offer", "plan-offer"), ("vip", "vip"), ("", "pricing"), ("", "intro"),
        ("included", "included"), ("counters.*", "counter"), ("goals", "goals"), ("goals.items.*", "goal"), ("steps", "steps"), ("steps.items.*", "step"),
        ("compare", "compare"), ("compare.rows.*", "compare-row"), ("faq.*", "faq-item"), ("gym", "gym"), ("train", "train"), ("changelog", "changelog"),
        ("changelog.items.*", "changelog-item"), ("gallery", "gallery"), ("gallery.items.*", "gallery-item"), ("pages.about", "page-about"), ("pages.terms", "page-terms"),
        ("pages.privacy", "page-privacy"), ("", "links"), ("", "seo"), ("developer", "developer"), ("visitors", "visitors"), ("", "look"), ("", "mood"),
        ("mood.list.morning.*", "mood-item"), ("mood.list.noon.*", "mood-item"), ("mood.list.evening.*", "mood-item"), ("mood.list.night.*", "mood-item"), ("maintenance", "maintenance"), ("offline", "offline"), ("notify", "bot"),
    ]
    static let topNames: [String: String] = [
        "gate": "حالة الاشتراكات", "mode": "وضع الموقع", "plans": "الباقات", "vip": "باقة VIP", "currency": "العملة", "bar": "شريط الاشتراك",
        "brand": "التعريف", "cta": "الأزرار", "included": "ما تشمله الباقات", "counters": "الأرقام", "goals": "اختر هدفك", "steps": "خطوات المتابعة",
        "compare": "جدول المقارنة", "faq": "الأسئلة الشائعة", "gym": "القاعة", "train": "وضع التدريب", "changelog": "تحديثات المنصة", "gallery": "معرض النتائج",
        "pages": "الصفحات", "links": "الروابط", "seo": "محركات البحث", "legal": "الحقوق", "developer": "بطاقة المطوّر", "visitors": "عدّاد المتصفحين",
        "ui": "المظهر الافتراضي", "mood": "الترحيب حسب الوقت", "maintenance": "صفحة الصيانة", "offline": "صفحة الإيقاف", "notify": "رسائل بوت التذكير",
        "geo": "الحظر", "app": "التحكم بالتطبيق", "texts": "نصوص الموقع", "modeBefore": "وضع الموقع",
    ]
    static func pattern(_ p: [Seg]) -> String { p.map { if case .index = $0 { return "*" }; return $0.description }.joined(separator: ".") }

    static func label(_ p: [Seg]) -> String {
        let pt = pattern(p)
        if pt == "gate.state" { return "حالة الاشتراكات" }
        if pt == "gate.text" { return "نص حالة الاشتراكات" }
        if pt.hasPrefix("gate.schedule") { return "جدولة الاشتراكات" }
        if pt == "mode" { return "وضع الموقع" }
        if pt.hasPrefix("texts.") { return "نصوص الموقع" }
        if pt.hasPrefix("geo") { return "الحظر" }
        var best: (Int, String)? = nil
        for (b, id) in bases {
            let f = Defs.form(id)
            for sec in f.sections {
                for fl in sec.fields {
                    let full = (b.isEmpty ? "" : b + ".") + fl.key.map(\.description).joined(separator: ".")
                    if pt == full || pt.hasPrefix(full + ".") {
                        let score = full.count
                        if best == nil || score > best!.0 { best = (score, f.title == fl.label ? fl.label : f.title + ": " + fl.label) }
                    }
                }
            }
            for l in f.lines {
                let full = (b.isEmpty ? "" : b + ".") + l.1
                if pt == full || pt.hasPrefix(full + ".") { if best == nil || full.count > best!.0 { best = (full.count, f.title + ": " + l.0) } }
            }
        }
        if let b = best { return b.1 }
        return topNames[p.first?.keyName ?? ""] ?? "إعدادات الموقع"
    }
    static func describe(_ paths: [[Seg]]) -> String {
        var out: [String] = []
        for p in paths { let l = label(p); if !out.contains(l) { out.append(l) } }
        let head = out.prefix(2).joined(separator: "، ")
        return out.count > 2 ? head + " و\(Fmt.n(out.count - 2)) غيرها" : (head.isEmpty ? "تعديل إعدادات الموقع" : head)
    }
}
