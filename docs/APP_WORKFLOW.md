# CoreGym — Full App Workflow (v1 — 2026-09-15)

> مصدر الحقيقة: مسح كامل للكود (lib/ + supabase/). كل اسم ملف/جدول/function مذكور موجود فعلاً.

---

## 1) Launch & Routing

```
main() — lib/main.dart
  |  Supabase.initialize (mkrjvrnysuvtokqkyoll)
  |  Providers: Locale / ThemeMode / Profile / Chat / Unread / Notifications
  |  (post first frame) NotificationService.init() + WaterReminderService.refresh()
  v
SplashScreen — 2.6s brand animation
  |  flight -> impact -> clover -> wordmark -> spinner
  |  bootstrap in parallel: _resolveDestination()
  v
supabase.auth.currentUser == null ?
  |-- YES --> OnboardingScreen (marketing, 3 pages, nothing persisted)
  |             |  Next / Skip / "already a member? sign in"
  |             v
  |           AuthWrapper
  |-- NO  --> ProfileProvider.fetchProfile()
                |
                |-- needsUserOnboarding  (onboarding.completed != true)
                |      --> OnboardingFlow (5 steps) --saveOnboarding()--+
                |-- isCoach && needsCoachSetup                          |
                |      (coach_onboarding.is_completed != true)          |
                |      --> CoachProfileSetupScreen ---------------------+
                |-- else --> FitnessHomePage <--------------------------+
  error at any step --> retryable splash error panel
```

## 2) Auth & Onboarding

```
AuthWrapper (lib/login_sign_up.dart)  [LanguageToggle in header]
  |-- LoginScreen
  |     |-- Email+Password -> AuthService.signInWithEmail -> fetchProfile -> _navigateAfterAuth()
  |     |-- Google         -> google_sign_in -> signInWithIdToken
  |     |                     (first-ever login, created_at < 2min -> welcome push after 6s)
  |     |-- Apple          -> "coming soon" snack
  |     '-- Forgot password -> ForgotPasswordScreen -> OTP -> ResetPasswordScreen
  '-- SignupScreen
        '-- Email+Name -> registerWithEmail(role: 'client' ALWAYS)
             -> upsert profiles{id,name,email,role:'client'} -> _navigateAfterAuth()
```

**قواعد الأدوار**: أي تسجيل من داخل التطبيق = `client` دايماً. الكوتشز بيتعملهم account من Core Dashboard website بس (`SupabaseConfig.dashboardUrl`).

**OnboardingFlow** (lib/screens/onboarding_flow.dart) — 5 steps، بدون حقل اسم (بيتشال من الـ signup):

1. Age (drum picker) + Gender cards
2. Height / Weight + BMI live
3. Goal (`muscle_gain` default)
4. Activity level (×1.2 / 1.375 / 1.55 / 1.725 / 1.9) + BMR/TDEE preview (Harris-Benedict للعرض)
5. Target weight + weekly workouts (default 4)

**`OnboardingService.saveOnboarding()`** — كتابة واحدة متسلسلة:

```
onboarding upsert (completed: true)
profiles update (age, gender, height_cm, weight_kg, fitness_goal)
BMR = Mifflin-St Jeor -> TDEE = BMR x multiplier
       weight_loss: -500 kcal | muscle_gain: +300 | floor 1200
user_goals upsert: protein 2g/kg | fat 25% kcal / 9 | carbs remainder / 4
body_measurements upsert (weight, today)
```

## 3) Navigation Skeleton

```
FitnessHomePage (lib/fitness_home_pages.dart) — liquid_tab_bar
+----------+------------+-----------+-----------+---------+
|  HOME *  | NUTRITION *|  WORKOUT  |  COACHES  | PROFILE*|   (* = visible in bar)
+----------+------------+-----------+-----------+---------+
WORKOUT & COACHES: مش ظاهرين في البار لكن عايشين (IndexedStack)
بيفتحهم Deep-link من Home "Explore app features" strip
Back من أي تاب -> HOME (PopScope)
```

## 4) Home Dashboard (`_HomeScreenCore`)

Load: health sync (3s cap) → parallel: `profiles` + `user_goals` + `nutrition_logs(today)` + `daily_summary(today)` + `StreakService.getStatus()`.
Defaults لما مفيش goals: 2400 kcal / 140P / 250C / 80F. Water = `water_ml ~/ 250`.

```
_KaleeHeader          greeting + streak badge + avatar + bell + chat
  |_ _StreakAtRiskBanner        (once/session when atRisk)
  |_ _GoalsOnboardingBanner     (when user_goals missing)
_HeroFuelCard         date stepper | calorie ring 124px (isOver -> warning color)
  |                   center % + kcal remaining + 3 macro bars (P/C/F)
_VitalsBar            Water /8 glasses (+250ml chip) | Steps /10000 (manual + watch sheet)
  |                   Burned /400 kcal | editing only if selected date == today
_AssignedWorkoutCard  فقط لو AssignedWorkoutService.fetchTodayAssignment() رجّع حاجة
_QuickFoodLogHub      AI Scan (row) | Voice | Text | Barcode | Add Meal
  |                   Add Meal default بالساعة: <11 breakfast / <16 lunch / <22 dinner / snack
_FeatureHighlightsStrip  Workouts | Coaches | Nutrition insights | Rankings
_MealsFeed            today logs grouped by meal + "Add Food"
```

Cross-cutting: pull-to-refresh، midnight rollover على resume، push-verify dialog مرة واحدة/تسطيب (هو المكان الوحيد اللي بيطلب `requestPermission()`)، streak milestone dialogs (7/30/100).

## 5) Nutrition Logging (أكبر flow)

**6 مداخل كلها بتوصل لنفس الـ save pipeline:**

```
HOME QuickFoodLogHub                          NUTRITION tab / Meals feed
  |-- AI Scan --> FoodScanScreen --(analyze-food: Gemini, food-scans bucket,
  |                                persists food_scans + food_scan_items)--+
  |-- Voice   --> VoiceFoodLogScreen --(log-food-voice: m4a,                    |
  |                                persists voice_food_logs + _items)-----------|---> confirm items
  |-- Text    --> TextFoodLogScreen --(log-food-text: stateless)---------------|
  |-- Barcode --> BarcodeScanScreen --(lookup-barcode: barcode_products)-------|
  '-- Add Meal --> FoodLoggingModal (2 tabs)  OR  AddFoodSheet (rich browser) <-+
                       |  foods catalog (~430) + FoodThumbnail (food-images bucket)
                       |  FoodFilter: category | calories 0..800 | protein 0..60 (AND, server-side)
                       |  search: name/name_ar ilike + rankFoods (exact > startsWith > position > alpha)
                       v  save
NutritionService.logFood()
  1. insert nutrition_logs  (8 micronutrients; PGRST204/42703 -> strip and retry)
  2. re-aggregate ALL logs of the day -> upsert daily_summary (user_id+summary_date)
  3. RPC record_daily_activity  (streak)
  4. maybeSendCalorieAlert: total >= 90% x daily_calories
        -> once/day (notification_log dedupe) -> edge fn send-notification (bilingual push)
```

AI presets للـ custom add: Scan = 480/35P/50C/14F، Voice = 350/25P/40C/10F.
`saveScannedItems/saveVoiceLogItems` بيرجعوا يكتبوا `nutrition_log_id` في `food_scan_items` / `voice_food_log_items`.
`fetch-dish-image` = server-side helper بس (Pexels → food-images bucket) — مش مندوحي من Dart.

## 6) Assigned Workout (client flow)

```
Home card (لو فيه assignment اليوم) --> AssignedWorkoutScreen
phases: loading -> none | ready -> active -> done

fetchTodayAssignment(): workout_assignments (client_id=me, scheduled_date=today,
  status in assigned|started) JOIN workout_templates + workout_template_exercises
  fresh 'assigned' قبل 'started' (resumable)

ready --Start--> startWorkout():
  insert workout_sessions {session_name, muscle_group (normalized, fallback full_body
  on 23514), started_at, assignment_id}  +  assignment.status = 'started'
active --per set--> logSet(): reps>0 -> insert workout_sets {exercise_name AS the
  template spells it, set_number, reps, weight_kg, rest_sec}
  -> haptic + refresh + rest countdown (restSec, default 60s, skippable)
  -> target hit highlight (reps AND weight)
active --Finish--> finishWorkout(): ended_at + duration_min
  -> recordActivity('workout') -> assignment.status = 'completed'
resume: لو فيه open session (ended_at null) بيرجع لـ active مع الـ sets المسجلة
```

ملاحظة معمارية: مفيش UI كوتش في التطبيق بيعمل assignment — الإنشاء بييجي من الـ Core Dashboard؛ التطبيق consumer بس. الـ Workout tab العادي: Log Workout (exercises table → workout_sessions/sets/exercise_progress)، My Program (user_active_program)، Programs Library (training_programs)، و PRs من personal_records.

## 7) Coaches & Subscriptions & Stripe

```
COACHES tab = CoachMarketplaceScreen (coaches + coach_onboarding banners)
  |-- CoachCard -> CoachDetailScreen (profile, gallery, reviews, price)
  |     |-- "Message" -> getOrCreateConversation -> ChatRoomScreen
  |     '-- Subscribe -> StripePaymentNotifier.subscribe(coachId, tier)
  '-- _SubscribeBottomSheet -> direct (free) subscribeToCoach

STRIPE PATH (client):
  1. edge fn create-checkout-session {coach_id, tier} -> {checkout_url, session_id}
  2. register deep-link listener (app_links)  <-- BEFORE launch
  3. launch Stripe Checkout (external browser, url_launcher)
  4a. success coregym://payment/success?session_id
        -> edge fn get-subscription-status -> 'paid' -> refresh ActiveSubscriptionNotifier
  4b. cancel coregym://payment/cancel -> failure state

SERVER (stripe-webhook, signature-verified):
  checkout.session.completed -> cancel old active + insert subscriptions(active, stripe_sub_id)
                                + payment_intents(succeeded)
  invoice.paid               -> reactivate + extend end_date + log payment
  customer.subscription.deleted/expired -> expired / cancelled

FREE PATH (SubscriptionRepositoryImpl.subscribeToCoach):
  cancel current active row -> insert {status active, tier standard, 30 days}
  (23505 duplicate -> return existing active row — idempotent)
```

## 8) Chat (clean architecture, lib/chat/)

```
ChatListScreen (from Home header/strip)
  -> conversations .or(client_id=me, coach_id=me) order by last_message_at
ChatRoomScreen
  -> messages (limit 50, pagination beforeMessageId, is_deleted=false)
  -> send: type text | voice | image | file
       buckets: chat-voice-notes (m4a) | chat-images | chat-files (signed URLs 1y)
  -> realtime: supabase channel onPostgresChanges INSERT on messages
       (dedupe by id, auto mark-read for others' msgs)
  -> markConversationRead = RPC mark_conversation_read | unread = RPC unread_count
  -> while room open: foreground pushes suppressed (setSuppressedConversation)

NEW MESSAGE PUSH (DB trigger notify_new_message -> pg_net -> edge fn send-chat-push):
  type-aware preview (voice/icon, photo, file, 60-char text)
  respects notification_preferences.chat_notifications_enabled
  logs to notification_log(type 'chat') + OneSignal data {conversation_id} for deep-link
```

## 9) Community / Rank

```
get_leaderboard(p_days=7)  -- RPC
  day_commitment_score = 60% calorie adherence + 40% water adherence (0..1)
  score = round(avg x 100), order: score desc, days_logged desc
Tiers: >=85 Diamond | >=70 Gold | >=50 Silver | >0 Bronze | else Unranked
LeaderboardScreen: podium top3 + search + "me" highlight + pinned my-rank card
  tap entry -> ClientProfileScreen
ClientProfileScreen: 35-day activity -> heatmap + trend chart (daily/weekly/cumulative, 7/30)
  colors: calories #B2D742 | water #4DA8DC | steps #E8894D
```

## 10) Notifications — الخريطة الكاملة

| النوع | القناة | التريجر/الميعاد | الشروط والـ dedupe |
|---|---|---|---|
| Welcome | OneSignal (edge `send-notification`) | بعد signup أو أول Google login، delay 6s | مرة واحدة |
| Meal reminders | OneSignal (edge `send-meal-reminders` + pg_cron `0 6,12,18 * * *` UTC) | 8ص / 2م / 8م Cairo | skip quiet hours + skip لو مسجل أي أكل النهاردة + dedupe لكل window (morning/afternoon/evening) |
| Water reminders | **Local** (flutter_local_notifications, TZ Africa/Cairo) | 8 slots: 8,10,12,14,16,18,20,22 | off عبر prefs؛ goal (2500ml default) يتحقق → reschedule بكره |
| Calorie alert | OneSignal | داخل `logFood` لما total ≥ 90% من الهدف | مرة/يوم |
| Chat push | OneSignal (edge `send-chat-push` ← DB trigger) | كل رسالة جديدة | حسب prefs + suppression لو الغرفة مفتوحة |

OneSignal login: listener على `onAuthStateChange` → `OneSignal.login(user.id)` (external_id). signOut → `OneSignal.logout()` أول حاجة. `notification_log` types: welcome | meal_reminder | water_reminder | calorie_alert | chat.

## 11) Coach Side (داخل نفس التطبيق)

- **Setup**: `CoachProfileSetupScreen` → avatar لـ bucket `coach-media` → insert `coach_onboarding` → insert `coaches` → `profiles.role='coach'`.
- **CoachDashboardScreen**: stats (active subscribers / avg rating من `reviews` / monthly revenue = Σ premium?price_premium:price_monthly / open slots) + قايمة `subscriptions` بـ status+payment badges + phases. مفيش زرار approve داخل التطبيق — activation من الـ webhook/dashboard.
- **ClientDataScreen**: 4 تابات (nutrition / workouts / measurements / daily summary) من `CoachDashboardRepositoryImpl.getClientData`.
- **Media**: `coach_media_service` → صور `coach-media`، PDFs `coach-pdfs`، rows في `coach_content`.
- الاشتراك المباشر (بدون Stripe) بيلغي الاشتراك النشط القديم ويعمل واحد جديد 30 يوم.

## 12) Profile, Streaks, Health

- **ProfilePage**: stats (sessions count/شهر، kcal، program، exercise_progress)، rank label ROOKIE/IRON/BRONZE/SILVER/GOLD، avatar upload → `coach-media/{userId}/avatar.jpg`، تعديل goals (profiles + user_goals)، LanguageToggle + ThemeModeToggle، Become a Coach، Sign out.
- **Streaks**: RPC `record_daily_activity` (workout/nutrition) + `get_streak_status`؛ milestones 7/30/100 (مرة واحدة لكل milestone)؛ atRisk → banner.
- **Health**: `health` plugin → `daily_activity` + `daily_summary` upsert؛ TodayActivityCard جوه watch sheet؛ manual steps entry موجود.

## 13) Data Map — الجداول الأساسية

- **Identity/Onboarding**: profiles, onboarding, user_goals, body_measurements, coach_onboarding, coaches
- **Nutrition**: nutrition_logs (+8 micronutrients), daily_summary, foods, food_scans, food_scan_items, voice_food_logs, voice_food_log_items, barcode_products, weekly_progress
- **Workout**: workout_assignments, workout_templates, workout_template_exercises, workout_sessions, workout_sets, exercises, training_programs, user_active_program, exercise_progress, personal_records
- **Social/Coach**: subscriptions, subscription_plans, subscription_phases, reviews, coach_content, stripe_customers, payment_intents
- **Chat/Notifications**: conversations, messages, notifications, notification_log, notification_preferences
- **Community**: daily_activity, RPCs: record_daily_activity, get_streak_status, get_leaderboard, get_user_activity, mark_conversation_read, unread_count

## 14) Edge Functions Inventory

| Function | Purpose |
|---|---|
| analyze-food | Gemini scan → food_scans + items |
| log-food-voice | Voice → voice_food_logs + items |
| log-food-text | Text parse (stateless) |
| lookup-barcode | Barcode → barcode_products |
| send-notification | Self-push (welcome/calorie alert) |
| send-chat-push | Chat message push (من الـ trigger) |
| send-meal-reminders | Cron 8ص/2م/8م Cairo |
| create-checkout-session | Stripe Checkout session |
| get-subscription-status | Deep-link success check |
| stripe-webhook | Source of truth للاشتراكات المدفوعة |
| fetch-dish-image | Pexels → food-images (server-side فقط) |
