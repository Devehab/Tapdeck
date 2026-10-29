# Tapdeck

[English](README.md) · [الموقع](https://devehab.github.io/Tapdeck/) · [تحميل](https://github.com/Devehab/Tapdeck/releases/latest/download/Tapdeck.dmg)

**One-tap Mac tools in Control Center** — أدوات ماك صغيرة بضغطة واحدة، موجّهة لمن يبرمج بالـ vibe coding ويريد أن تعمل الأشياء بلا تعقيد.

مجموعة أدوات لـ **Control Center** في macOS 26. التطبيق نفسه بلا نافذة ولا أيقونة في الـ Dock أو شريط القوائم؛ يظهر فقط كأزرار تضيفها إلى Control Center (أو إلى شريط القوائم)، وكإجراءات في Spotlight وتطبيق Shortcuts.

## الأدوات الحالية

### Lights Out
زر واحد يطفئ الشاشة وإضاءة الكيبورد والجهاز شغّال:

1. يحفظ سطوع الشاشة الحالي، ومستوى إضاءة الكيبورد، وحالة "Adjust keyboard brightness in low light".
2. ينزّل سطوع الشاشة إلى 0، ويجعل الصورة سوداء تماماً (على شاشات mini‑LED تنطفئ مناطق الإضاءة فعلاً)، ويطفئ إضاءة الكيبورد.
3. يمنع الجهاز والشاشة من الدخول في السكون أثناء ذلك، فتستمر المهام الشغّالة، وعند الرجوع لا تظهر شاشة القفل.
4. أول لمسة للتراكباد أو الماوس أو أي زر في الكيبورد (بعد ثانية تقريباً من الضغط) ترجع كل شيء كما كان بالضبط. إذا كانت إضاءة الكيبورد مطفأة قبلها تبقى مطفأة.

لا يحتاج أي صلاحيات (لا Accessibility ولا Input Monitoring).

### Stay Awake
زر تبديل (toggle) يبقي الجهاز شغّالاً دائماً، حتى لو سكّرت غطاء اللابتوب. هو نفس:

```bash
sudo pmset -a disablesleep 1   # تشغيل
sudo pmset -a disablesleep 0   # إيقاف
```

- الزر يقرأ حالة النظام الحقيقية، ولو غيّرتها من التيرمنال يعرض الحالة الصحيحة:
  - ☀️ شمس برتقالية + **Won't Sleep** = الجهاز لن ينام، حتى لو سكّرت الغطاء.
  - 🌙 قمر رمادي + **Sleeps Normally** = الجهاز ينام كالعادة.
  - في شريط القوائم تظهر الأيقونة وحدها، والشمس والقمر يكفيان لمعرفة الحالة.
- ضغطة واحدة تبدّل الحالة.
- لأن الأمر يحتاج root، ينفّذه helper صغير يعمل كـ root. التطبيق يسجّله، ويحتاج **موافقتك مرة واحدة فقط**: عند أول ضغطة تظهر رسالة، اضغط **Open System Settings**، ثم فعّل **Tapdeck** تحت **Allow in the Background** في General ← Login Items & Extensions. بعدها يطبّق التطبيق الحالة التي طلبتها تلقائياً.
- الـ helper لا يقدر ينفّذ إلا `pmset -a disablesleep 0/1`، ولا يقبل الطلبات إلا من هذا التطبيق الموقّع بنفس الفريق.

⚠️ لا تضع اللابتوب مغلقاً في حقيبة وهذه الخاصية مفعّلة: يبقى شغّالاً، فيسخن ويستهلك البطارية.

#### التأكد من التيرمنال

```bash
pmset -g | grep SleepDisabled
```
النتيجة `SleepDisabled 1` = مفعّل، و `0` = ملغى.

```bash
pmset -g stats
```
سجّل قيمة `Sleep Count`، سكّر الغطاء دقيقة أو اثنتين ثم افتحه، وشغّل الأمر مرة ثانية. إذا لم يزد الرقم، فالجهاز لم ينم.

### Mic Mute
زر تبديل يكتم كل الميكروفونات مرة واحدة، مثل زر الكتم في الميكروفون الخارجي:

- يقلب مفتاح الكتم الخاص بكل ميكروفون على مستوى الجهاز. التطبيقات تبقى متصلة وتحتفظ بصلاحيتها، وتستقبل صمتاً رقمياً تاماً؛ لا شيء يُسحب أو يتوقف أو يحتاج إعادة تشغيل.
- ضغطة ثانية ويرجع الصوت فوراً. ميكروفون أحمر مشطوب = **Muted**، ميكروفون عادي = **On**.
- أي ميكروفون يتصل أثناء الكتم يُكتم أيضاً، والكتم يبقى حتى لو أُغلق Tapdeck.
- إذا أعاد تطبيق آخر تشغيل الميكروفون، يتبعه الزر ويعرض الحالة الحقيقية.
- لا يحتاج أي صلاحيات، ولا يستمع للميكروفون أبداً.
- بعض المداخل ليس فيها أي تحكم بالكتم أو الصوت، مثل الآيفون عبر Continuity أو الميكروفونات الافتراضية من برامج التسجيل. إذا كان المدخل المستخدم منها، يخبرك Tapdeck بدل أن يُظهر كتماً غير حقيقي. الأمر `Tapdeck --status` يعرض كل المداخل وهل يمكن كتمها.

تم اختباره بتسجيل حقيقي: أثناء الكتم استقبل التطبيق المسجِّل أصفاراً تامة، ولم يتوقف تسجيله ولم يظهر له أي خطأ.

### Spotlight واختصارات الكيبورد
- اضغط ⌘ Space واكتب **Lights Out** أو **Toggle Stay Awake** أو **Toggle Mic Mute**. تعمل مباشرة بعد التثبيت (معرّفة في `App/AppShortcuts.swift`).
- لاختصار كيبورد: تطبيق Shortcuts ← اختصار جديد ← ابحث عن Tapdeck وأضف الإجراء ← تفاصيل الاختصار (ⓘ) ← **Add Keyboard Shortcut**.

## Terminal وإضافات المتصفح

كل أداة يمكن قراءتها والتحكم بها من خارج Control Center أيضاً، دون أي سيرفر:

```bash
/Applications/Tapdeck.app/Contents/MacOS/Tapdeck install-cli   # مرة واحدة: يضيف أمر tapdeck إلى ~/.local/bin
tapdeck status --json
tapdeck mic toggle
tapdeck awake on
tapdeck lights out
```

إضافات المتصفح تصل إلى Tapdeck عبر native messaging في Chrome: شغّل `tapdeck chrome install`، ثم حمّل الإضافة الجاهزة ([نزّل ملف zip](https://github.com/Devehab/Tapdeck/releases/latest/download/tapdeck-chrome-extension.zip)، أو استخدم [`extensions/chrome`](extensions/chrome)). نافذتها تعرض الأدوات الثلاث، والاختصار Alt+Shift+M يبدّل كتم الميكروفون.

الشرح الكامل، بكل الأوامر وصيغة JSON وطريقة صنع إضافتك الخاصة وحل المشاكل، موجود في [docs/integrations.ar.md](docs/integrations.ar.md).

## التطوير والتثبيت على جهازك

أول مرة فقط: ضع Team ID الخاص بحسابك في Apple Developer داخل هذا الملف (لا يُرفع إلى git):

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

ثم:

```bash
./scripts/install.sh
```

يبني التطبيق، يثبّته في `/Applications/Tapdeck.app`، ويسجّل الأزرار. بعدها: Control Center ← **Edit Controls** ← **Tapdeck** ← اسحب **Lights Out** و **Stay Awake** و **Mic Mute**.

أعد تشغيل نفس السكربت بعد أي تعديل على الكود. كل build يأخذ رقماً جديداً تلقائياً، لأن النظام يحفظ قائمة الأزرار حسب رقم البناء؛ والسكربت يوقف نسخة الأزرار القديمة حتى يُرسم الجديد.

| السكربت | ماذا يفعل |
|---|---|
| `scripts/build.sh` | يبني `Tapdeck.app` (Release، Universal) برقم build جديد |
| `scripts/install.sh` | يبني ويثبّت على هذا الجهاز |
| `scripts/make-dmg.sh` | يبني ملف التوزيع `dist/Tapdeck-<version>.dmg` ونسخة باسم ثابت `dist/Tapdeck.dmg` للإصدار على GitHub |
| `scripts/make-icon.swift` | يرسم أيقونة التطبيق وأيقونات الموقع |

## التوزيع: DMG وصفحة الهبوط

```bash
./scripts/make-dmg.sh
```

ثم انشر الإصدار على GitHub. زر التحميل في الصفحة يشير دائماً إلى `Tapdeck.dmg` في آخر إصدار:

```bash
gh release create v1.0 dist/Tapdeck.dmg --title "Tapdeck 1.0"
```

صفحة الهبوط في `site/index.html` (عربي وإنجليزي، فاتح وداكن)، وتُنشر تلقائياً على GitHub Pages عند كل push يغيّر مجلد `site/` (عبر `.github/workflows/pages.yml`). لمعاينتها محلياً:

```bash
python3 -m http.server 8765 --directory site
```

⚠️ **التوثيق (Notarization):** الإصدار الحالي موقّع بشهادة **Apple Development** من حساب مطوّر مجاني، لذلك:
- عند تحميله على جهاز آخر، يطلب macOS في أول تشغيل تأكيداً من Privacy & Security ← **Open Anyway** (الصفحة تشرح ذلك خطوة بخطوة).
- لم يُجرَّب بعد على جهاز ثانٍ، وبالأخص تسجيل الـ helper الخاص بـ Stay Awake.
- للتوزيع العام بدون هذه الخطوة: اشترك في Apple Developer Program، ووقّع بـ **Developer ID Application**، ووثّق الـ DMG بـ `notarytool`. بعدها احذف قسم "First launch" من الصفحة.

## بنية المشروع

```
Tapdeck/
├── App/                      ← التطبيق (غير sandboxed): ينفّذ العمل الفعلي
│   ├── AppDelegate.swift     ← نقطة البداية، رسالة الترحيب، استقبال tapdeck://، استرجاع الحالة بعد crash
│   ├── AppShortcuts.swift    ← الإجراءات التي تظهر في Spotlight و Shortcuts
│   ├── Intents/              ← intents خاصة بالتطبيق (مثل Toggle Stay Awake)
│   ├── TapdeckActionHandler.swift   ← يوجّه كل TapdeckAction إلى الميزة الخاصة بها
│   ├── Features/LightsOut/   ← منطق Lights Out
│   ├── Features/StayAwake/   ← منطق Stay Awake وطلب الموافقة على الـ helper
│   └── Hardware/             ← سطوع الشاشة، إضاءة الكيبورد، آخر إدخال، الاتصال بالـ helper
├── ControlsExtension/        ← WidgetKit extension: أزرار Control Center
│   ├── TapdeckBundle.swift  ← قائمة كل الأزرار
│   ├── Controls/
│   └── TapdeckActionHandler.swift   ← يمرّر الأمر للتطبيق عبر tapdeck://
├── Shared/                   ← مشترك بين التطبيق والـ extension: TapdeckAction، ControlKind، الـ App Intents
├── Helper/                   ← TapdeckHelper: daemon يعمل كـ root لأي أمر يحتاج sudo
├── HelperInterface/          ← بروتوكول XPC المشترك بين التطبيق والـ helper
├── Config/                   ← Info.plist و entitlements و launchd plist للـ helper، و Signing.xcconfig
├── site/                     ← صفحة الهبوط (index.html + assets/)، تُنشر على GitHub Pages
└── scripts/                  ← build.sh و install.sh و make-dmg.sh و make-icon.swift
```

أي أداة مستقبلية تحتاج root تضيف دالة جديدة إلى `TapdeckHelperProtocol`، وتنفّذها في `Helper/HelperService.swift`. الأفضل أن تبقى كل دالة عملية محددة، وليس "نفّذ أي أمر".

الـ extension محصور داخل sandbox ويعيش لثوانٍ فقط، لذلك لا يلمس الأجهزة بنفسه؛ يفتح `tapdeck://<action>` فيستلمه التطبيق في الخلفية (ويشغّل نفسه إذا كان مغلقاً) بدون أن يأخذ الـ focus.

## إضافة أداة جديدة

1. أضف case جديدة إلى `TapdeckAction` في `Shared/TapdeckAction.swift`.
2. نفّذها في `App/TapdeckActionHandler.swift`، والأفضل في مجلد خاص تحت `App/Features/`.
3. أنشئ intent في `Shared/Intents/` يستدعي `TapdeckAction.<case>.run()`.
4. أضف `ControlKind` جديداً في `Shared/ControlKind.swift`، وأنشئ `ControlWidget` في `ControlsExtension/Controls/` وأضفه إلى `TapdeckBundle`.
5. (اختياري) أضفها إلى `App/AppShortcuts.swift` لتظهر في Spotlight.
6. أضف بطاقة لها في قسم Tools في `site/index.html`.
7. شغّل `./scripts/install.sh`.

المجلدات متصلة بالمشروع مباشرة (synchronized folders)، فأي ملف جديد تضعه فيها يدخل الـ build تلقائياً.

## استكشاف الأخطاء

```bash
/Applications/Tapdeck.app/Contents/MacOS/Tapdeck --status
```
يعرض ما يراه التطبيق (الشاشات، السطوع، الكيبورد، الوقت منذ آخر إدخال، حالة Stay Awake، حالة الـ helper، وكل الميكروفونات وهل يمكن كتمها) بدون أن يغيّر شيئاً.

```bash
/usr/bin/log show --last 10m --style compact --predicate 'subsystem == "com.ibtkrgo.Tapdeck"'
```
سجل التطبيق والـ extension. (في zsh، `log` أمر داخلي، لذلك استخدم المسار الكامل.)

إذا ظل السطوع منخفضاً بعد crash، فأول تشغيل للتطبيق يرجّعه تلقائياً.

## ملاحظات

- سطوع الشاشة وإضاءة الكيبورد يتم التحكم بهما عبر واجهات خاصة من Apple (`DisplayServices` و `CoreBrightness`). هذا لا يمر في App Store، وقد يتغيّر مع تحديثات macOS. أمر `--status` يكشف ذلك بسرعة.
- الشاشات الخارجية التي لا تدعم التحكم بالسطوع تصبح سوداء فقط، وإضاءتها الخلفية تبقى شغّالة.
- مدة التجاهل بعد الضغط (1.2 ثانية) ومنع السكون موجودة في أعلى `LightsOutController.swift`.
- إزالة التطبيق: أطفئ Stay Awake و Mic Mute أولاً، ثم شغّل `/Applications/Tapdeck.app/Contents/MacOS/Tapdeck --unregister-helper`، ثم أغلق التطبيق (`pkill -x Tapdeck`) واحذف `/Applications/Tapdeck.app`.

## الرخصة

MIT. راجع [LICENSE](LICENSE).
