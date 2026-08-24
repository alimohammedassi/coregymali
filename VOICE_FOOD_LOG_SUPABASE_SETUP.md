# ميزة تسجيل الأكل بالصوت — اللي اتعمل في Supabase وطريقة الربط

## 1. اللي اتعمل بالفعل في قاعدة البيانات (مشروع coregymali)

### جدول `voice_food_logs` (رأس كل تسجيل صوتي)
| العمود | النوع | ملاحظات |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | FK → profiles.id |
| audio_path | text | مسار الملف الصوتي في الـ storage |
| transcript | text | النص اللي Gemini فهمه من الصوت |
| is_food | boolean | هل فيه وصف أكل فعلاً |
| confidence | text | `low` / `medium` / `high` |
| notes | text | ملاحظات اختيارية من الـ AI |
| logged_at, created_at | timestamptz | |

### جدول `voice_food_log_items` (كل صنف أكل مستخرج من التسجيل)
| العمود | النوع | ملاحظات |
|---|---|---|
| id | uuid | PK |
| log_id | uuid | FK → voice_food_logs.id |
| name, name_ar | text | |
| estimated_weight_g, calories, protein_g, carbs_g, fat_g | numeric | |
| nutrition_log_id | uuid | FK → nutrition_logs.id (nullable، بيتحدد لما المستخدم يحفظ) |
| created_at | timestamptz | |

**RLS:** مفعّل بالكامل على الجدولين — كل مستخدم يشوف/يعدّل/يمسح بياناته بس (نفس نمط `food_scans`).

### Storage bucket: `voice-food-logs`
- Private (مش public)
- RLS policies: كل مستخدم يقدر يرفع/يقرا/يمسح الملفات اللي جوا فولدر اسمه بالـ user_id بتاعه بس، بنفس نمط `food-scans`
- مسار الحفظ: `{user_id}/{log_id}.m4a`

### Edge Function: `log-food-voice`
- محتاج deploy (لسه ماتعملهاش):
  ```bash
  supabase functions deploy log-food-voice
  ```
- بتستخدم نفس `GEMINI_API_KEY` الموجود بالفعل — مفيش secret جديد مطلوب
- الفرق عن `analyze-food`: هنا بتستخدم **Gemini 3.6/2.0 Flash بقدرته على فهم الصوت مباشرة** — يعني مفيش خطوة "speech-to-text" منفصلة؛ نفس الطلب بيرجع النص المكتوب (`transcript`) + الأصناف والسعرات في نفس الوقت
- الفانكشن دي بتعمل الحفظ بنفسها (رفع الصوت + insert في الجدولين) قبل ما ترجع الرد، فمفيش خطوة "save" منفصلة من الفلاتر زي ميزة الصور — النتيجة اللي بترجع فيها الـ ids الحقيقية من الداتابيز على طول

## 2. طريقة الربط مع تطبيق الفلاتر

### الباكدجات المطلوبة (أضفهم في pubspec.yaml)
```yaml
dependencies:
  record: ^5.1.2          # تسجيل الصوت من المايك
  path_provider: ^2.1.4    # لتحديد مكان حفظ الملف مؤقتًا
```

### الصلاحيات
- **iOS** `ios/Runner/Info.plist`: أضف `NSMicrophoneUsageDescription`
- **Android** `AndroidManifest.xml`: أضف
  `<uses-permission android:name="android.permission.RECORD_AUDIO" />`

### تدفق الاستخدام (من الفلاتر)
1. المستخدم يدوس زرار التسجيل → `VoiceFoodLogService.startRecording()`
2. يدوس تاني يوقف → `stopRecording()` بترجع الملف
3. `logFromAudio(file)` بترفع الصوت (base64) للـ Edge Function عن طريق
   `supabase.functions.invoke('log-food-voice', ...)` — الـ JWT بتاع
   المستخدم بينضاف تلقائي، مفيش API key في الفلاتر خالص
4. الفانكشن بترجع `VoiceFoodLogResult` فيه: `transcript`, `items`
   (بمعرّفاتها الحقيقية من `voice_food_log_items`), والسعرات/الماكروز
5. زي ميزة الصور بالظبط، آخر خطوة (لما المستخدم يأكد "حفظ") هي إدخال
   صف في `nutrition_logs` لكل صنف، وتحديث `nutrition_log_id` في
   `voice_food_log_items` — دي بتتعمل من `nutrition_service.dart`
   الموجود عندك بالفعل، مش من الفانكشن

### الملفات الجاهزة
```
supabase/functions/log-food-voice/index.ts      # الفانكشن كاملة
lib/models/voice_food_log_result.dart           # الموديلات
lib/services/voice_food_log_service.dart        # التسجيل + استدعاء الفانكشن
```
شاشة الـ UI (تسجيل → استماع → نتيجة → حفظ) لسه محتاجة تتعمل — لو عايز
أعملها بنفس ستايل `food_scan_screen.dart` قولّي.

## 3. حد الاستخدام
نفس الـ Free Tier بتاع Gemini اللي اتكلمنا عنه (20 طلب/يوم للمشروع
كله) — كل تسجيل صوتي = طلب واحد لـ Gemini، فبيتحسب من نفس الكوتة
اليومية اللي بتتقسم مع ميزة تصوير الأكل.
