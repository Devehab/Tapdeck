# التحكم بـ Tapdeck من Terminal والسكربتات وإضافات المتصفح

[English](integrations.md) · [العودة إلى README](../README.ar.md)

كل ما يفعله Tapdeck من Control Center يمكن قراءته والتحكم به من الخارج أيضاً: أمر `tapdeck` للـ Terminal والسكربتات، وطريقة اتصال (native messaging) لإضافات المتصفح. لا يحتاج أي منهما سيرفر: لا شيء يستمع على أي بورت، ولا شيء يبقى شغّالاً في الخلفية.

- [كيف يعمل](#كيف-يعمل)
- [الجزء 1: أمر `tapdeck`](#الجزء-1-أمر-tapdeck)
- [الجزء 2: Chrome والمتصفحات الأخرى](#الجزء-2-chrome-والمتصفحات-الأخرى)
- [حل المشاكل](#حل-المشاكل)

## كيف يعمل

```
 Terminal، سكربت، Raycast، وكيل ذكاء اصطناعي ──┐
                                              ├─▶ Tapdeck (نفس ملف التطبيق)
 إضافة Chrome (عبر native messaging) ──────────┘        │
                                                       ├─ يقرأ الحالة مباشرة من macOS
                                                       │    مفتاح كتم الميكروفون (CoreAudio)
                                                       │    SleepDisabled (إعدادات الطاقة)
                                                       │    حالة Lights Out
                                                       │
                                                       └─ يسلّم أي تغيير لتطبيق Tapdeck
                                                            عبر tapdeck://، نفس الطريق
                                                            الذي تستخدمه أزرار Control Center
```

- **القراءة** فورية ودائماً صحيحة، لأنها من النظام مباشرة. تبقى صحيحة حتى لو كان Tapdeck مغلقاً أو غيّر برنامج آخر الإعداد.
- **التغيير** يمر عبر تطبيق Tapdeck تماماً كأنك ضغطت زر Control Center. لذلك تتحدّث الأزرار، ويُكتم أي ميكروفون جديد يتصل، ويرجع Lights Out عند أول لمسة. إذا كان Tapdeck مغلقاً يُفتح في الخلفية دون أن يأخذ التركيز.
- **الأمان لا يتغيّر.** كتم الميكروفون لا يحتاج أي صلاحية. Stay Awake ما زال يمر عبر البرنامج المساعد الذي لا يقبل إلا من Tapdeck نفسه. والمتصفح لا يصل إلى Tapdeck إلا من الإضافات التي سمحت لها.

---

## الجزء 1: أمر `tapdeck`

### التثبيت (مرة واحدة)

```bash
/Applications/Tapdeck.app/Contents/MacOS/Tapdeck install-cli
```

هذا يضع سكربتاً صغيراً اسمه `tapdeck` في `~/.local/bin`. إذا لم يكن هذا المجلد ضمن الـ PATH بعد، يطبع لك الأمر السطر الذي تضيفه إلى `~/.zshrc`. لتثبيته في مكان آخر، اكتب المجلد بعد الأمر: `… install-cli /usr/local/bin` (هذا المجلد يحتاج `sudo`).

### الأوامر

| الأمر | ماذا يفعل |
|---|---|
| `tapdeck status` | حالة كل الأدوات |
| `tapdeck mic` | حالة Mic Mute |
| `tapdeck mic mute` / `unmute` / `toggle` | كتم كل الميكروفونات على مستوى الجهاز أو إلغاء الكتم |
| `tapdeck awake` | حالة Stay Awake |
| `tapdeck awake on` / `off` / `toggle` | إبقاء الماك شغّالاً والغطاء مغلق، أو لا |
| `tapdeck lights` | حالة Lights Out |
| `tapdeck lights out` | إطفاء الشاشة وإضاءة الكيبورد؛ أي لمسة ترجعهما |
| `tapdeck lights on` | إرجاعهما من سكربت |
| `tapdeck status --verbose` | تشخيص كامل: الشاشات، إضاءة الكيبورد، كل الميكروفونات |
| `tapdeck chrome install [ID…]` | ربط المتصفحات (الجزء 2) |
| `tapdeck help` | كل ما سبق |

أضف `--json` لأي أمر لتحصل على مخرجات تقرأها البرامج.

### المخرجات

```
$ tapdeck mic mute
Microphone   Muted  (MacBook Pro Microphone)
Stay Awake   Won't Sleep
Lights Out   Off
```

```
$ tapdeck status --json
{
  "ok" : true,
  "state" : {
    "lightsOut" : { "out" : false },
    "micMute" : { "canMute" : true, "input" : "MacBook Pro Microphone", "muted" : true },
    "stayAwake" : { "helper" : "enabled", "on" : true }
  }
}
```

| الحقل | معناه |
|---|---|
| `ok` | `true` إذا وصلت الحالة إلى ما طلبته |
| `error` | يظهر فقط عندما يكون `ok` = `false`: ما الذي حصل وكيف تصلحه |
| `state.micMute.muted` | الميكروفون الذي تستخدمه التطبيقات افتراضياً مكتوم |
| `state.micMute.input` | اسم هذا الميكروفون |
| `state.micMute.canMute` | `false` للميكروفونات التي لا يعطيها macOS أي تحكم بالكتم أو الصوت (الآيفون عبر Continuity، وبعض الميكروفونات الافتراضية) |
| `state.stayAwake.on` | `pmset -a disablesleep` مفعّل |
| `state.stayAwake.helper` | `enabled` أو `needs-approval` أو `not-registered` (موافقة Stay Awake لمرة واحدة) |
| `state.lightsOut.out` | Lights Out مفعّل الآن |

**رموز الخروج (exit codes):** `0` تم، `1` لم يحصل التغيير (الرسالة تشرح السبب)، `2` الأمر غير مفهوم.

### أمثلة

اكتم الميكروفون قبل تسجيل، مهما كانت حالته:

```bash
tapdeck mic mute && echo "Mic is muted"
```

اقرأ قيمة واحدة باستخدام `jq`:

```bash
tapdeck status --json | jq '.state.micMute.muted'
```

أبقِ الماك مستيقظاً لمهمة طويلة، ثم أرجع كل شيء:

```bash
tapdeck awake on
./run-the-long-build.sh
tapdeck awake off
```

شغّل مهمة طويلة والشاشة مطفأة؛ ترجع الشاشة عندما تلمس الماك:

```bash
tapdeck awake on && tapdeck lights out
```

**أمر سكربت في Raycast** (احفظه باسم `toggle-mic.sh` في مجلد سكربتات Raycast):

```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Mic Mute
# @raycast.mode silent
~/.local/bin/tapdeck mic toggle --json | grep -q '"muted" : true' && echo "Mic muted" || echo "Mic on"
```

**وكلاء البرمجة بالذكاء الاصطناعي** (Claude Code و Cursor وغيرها) يستطيعون تشغيل `tapdeck status --json` لمعرفة الحالة، و `tapdeck mic mute` و `tapdeck awake on` وغيرها لتغييرها، مثل أي أمر Terminal آخر.

**تطبيق Shortcuts:** أضف إجراء *Run Shell Script* وفيه `~/.local/bin/tapdeck mic toggle`. إجراءات Tapdeck نفسها (*Toggle Mic Mute* و *Toggle Stay Awake* و *Lights Out*) موجودة هناك أيضاً دون أي سكربت.

---

## الجزء 2: Chrome والمتصفحات الأخرى

### كيف يعمل: native messaging بلا سيرفر

في Chrome طريقة مدمجة تسمح للإضافات بالتحدث مع تطبيق على الكمبيوتر، اسمها **native messaging**:

1. الإضافة تستدعي `chrome.runtime.sendNativeMessage("com.ibtkrgo.tapdeck", {command: "mic", action: "toggle"})`.
2. يبحث Chrome عن `com.ibtkrgo.tapdeck` في ملف صغير (*host manifest*) يحدد البرنامج الذي يشغّله والإضافات المسموح لها.
3. يشغّل Chrome تطبيق Tapdeck ويمرّر له معرّف الإضافة، ويرسل الرسالة عبر المدخل القياسي (stdin) ويقرأ الرد من المخرج القياسي (stdout).
4. يرد Tapdeck بالحالة الكاملة ثم ينتهي.

لا يُفتح أي بورت، فلا يستطيع أي موقع الوصول إلى Tapdeck، وفقط الإضافات المذكورة في الملف تستطيع ذلك.

### بداية سريعة مع الإضافة الجاهزة

في المستودع إضافة جاهزة في [`extensions/chrome`](../extensions/chrome). نافذتها تعرض الأدوات الثلاث بحالتها الحية. أيقونتها في شريط الأدوات تعرض شارة حمراء **MUTE** طالما الميكروفون مكتوم، والاختصار **Alt+Shift+M** يبدّل كتم الميكروفون طالما Chrome في المقدمة.

1. **ثبّت Tapdeck** في Applications وافتحه مرة واحدة.
2. **اربط متصفحاتك:**
   ```bash
   /Applications/Tapdeck.app/Contents/MacOS/Tapdeck chrome install
   ```
   هذا يكتب ملف الربط لكل متصفح مبني على Chromium عندك (Chrome و Brave و Edge و Arc و Vivaldi و Chromium). الإضافة الجاهزة مسموحة دائماً.
3. **حمّل الإضافة:** نزّل [tapdeck-chrome-extension.zip](https://github.com/Devehab/Tapdeck/releases/latest/download/tapdeck-chrome-extension.zip) وفك ضغطه (أو استخدم مجلد `extensions/chrome` من المستودع). افتح `chrome://extensions`، فعّل **Developer mode** (أعلى اليمين)، اضغط **Load unpacked** واختر المجلد بعد فك الضغط.
4. **ثبّتها** من قائمة قطعة البازل واضغط عليها. يجب أن ترى **Connected**.

ملف الإضافة الجاهزة يحتوي مفتاحاً عاماً ثابتاً، لذلك معرّفها دائماً `jcpfohebbppapakgjnigbikckpfjinci` أينما حمّلتها. لهذا لا تحتاج الخطوة 2 أي معرّف.

لتغيير الاختصار: `chrome://extensions/shortcuts`.

### اصنع إضافتك الخاصة

**1. اطلب الصلاحية** في `manifest.json`:

```json
{
  "manifest_version": 3,
  "name": "My Tapdeck panel",
  "version": "1.0",
  "permissions": ["nativeMessaging"],
  "action": { "default_popup": "popup.html" }
}
```

**2. أرسل رسالة.** طلب واحد ورد واحد:

```js
const reply = await chrome.runtime.sendNativeMessage("com.ibtkrgo.tapdeck", { command: "status" });
console.log(reply.state.micMute.muted);
```

أو أبقِ الاتصال مفتوحاً لعدة طلبات:

```js
const port = chrome.runtime.connectNative("com.ibtkrgo.tapdeck");
port.onMessage.addListener((reply) => console.log(reply.state));
port.postMessage({ command: "mic", action: "mute" });
port.postMessage({ command: "awake", action: "status" });
```

**3. اسمح لإضافتك.** انسخ معرّفها من `chrome://extensions` ثم شغّل:

```bash
tapdeck chrome install abcdefghijklmnopabcdefghijklmnop
```

المعرّفات التي تضيفها تبقى محفوظة عند تشغيل `chrome install` مرة أخرى. والأمر `tapdeck chrome status` يعرض المسموح.

### البروتوكول

| الطلب | معناه |
|---|---|
| `{"command": "status"}` | حالة كل شيء |
| `{"command": "mic", "action": "mute" \| "unmute" \| "toggle" \| "status"}` | Mic Mute |
| `{"command": "awake", "action": "on" \| "off" \| "toggle" \| "status"}` | Stay Awake |
| `{"command": "lights", "action": "out" \| "on" \| "status"}` | Lights Out |

كل رد له نفس شكل `tapdeck status --json`: الحقول `ok` و `state`، و `error` عندما لا يحصل التغيير. الطلب الخاطئ أو غير المعروف يحصل على `"ok": false` مع شرح، ولا يتعطل أي شيء.

تحت الغطاء، كل رسالة عبارة عن طول من 32 بت (بترتيب بايتات الجهاز) يليه نص JSON بذلك الطول. Chrome يتولى هذا بنفسه؛ يهمك فقط إذا كتبت برنامج الطرف الآخر بنفسك.

### المتصفحات الأخرى

- **Brave و Edge و Arc و Vivaldi و Chromium:** يغطيها `tapdeck chrome install` تلقائياً، بشرط أن يكون المتصفح قد فُتح مرة واحدة (حتى يوجد مجلد إعداداته). تحمّل الإضافة بنفس الطريقة.
- **Firefox:** يدعم native messaging أيضاً، لكن ملف الربط فيه بصيغة مختلفة (`allowed_extensions`) وفي مجلد مختلف، ولا يُجهَّز تلقائياً بعد.
- **Safari:** إضافاته تتصل بالتطبيقات بطريقة مختلفة وغير مدعومة.

---

## حل المشاكل

| ما تراه | السبب | الحل |
|---|---|---|
| `tapdeck: command not found` | الأمر غير مثبّت، أو `~/.local/bin` ليس ضمن الـ PATH | شغّل `…/Tapdeck install-cli` وأضف السطر الذي يطبعه إلى `~/.zshrc`، أو استخدم المسار الكامل `/Applications/Tapdeck.app/Contents/MacOS/Tapdeck` |
| الإضافة تقول **Chrome can't find Tapdeck yet** (*Specified native messaging host not found*) | ملف الربط غير مثبّت لهذا المتصفح | شغّل `tapdeck chrome install` ثم افتح الإضافة من جديد. إذا لم تفتح المتصفح من قبل، افتحه مرة أولاً |
| الإضافة تقول **Tapdeck doesn't allow this extension yet** (*Access … is forbidden*) | معرّف إضافتك ليس في الملف | شغّل `tapdeck chrome install <معرّف إضافتك>` |
| *Native host has exited* | الملف يشير إلى Tapdeck تم نقله أو حذفه | ضع Tapdeck في Applications وشغّل `tapdeck chrome install` من جديد |
| `"ok": false` مع `awake on` و `"helper": "needs-approval"` | موافقة Stay Awake لمرة واحدة غير موجودة | فعّل Tapdeck في System Settings › General › Login Items & Extensions › Allow in the Background |
| `"ok": false` مع `mic mute` و `"canMute": false` | الميكروفون المستخدم بلا تحكم بالكتم في macOS | اختر ميكروفوناً آخر من System Settings › Sound. كل الميكروفونات الأخرى كُتمت |
| `"ok": false`: *Tapdeck didn't respond in time* | لم يستطع Tapdeck أن يعمل | افتح Tapdeck مرة من Applications ثم حاول من جديد |

لإزالة كل شيء: `tapdeck chrome uninstall`، ثم احذف `~/.local/bin/tapdeck` وأزل الإضافة من `chrome://extensions`.
