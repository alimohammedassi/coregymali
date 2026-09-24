# CoreGym — Master Project Context

> **Purpose:** hand this single file to any AI assistant and it understands the project immediately — what it is, how it is built, what exists, what is broken, and how the owner likes to work.
> **Last updated:** 2026-09-24. Compiled from a full code scan, git history, and live-verified sessions on real devices.
> **Sources of truth:** this file (context + state) · `docs/APP_WORKFLOW.md` (detailed user flows, v1 2026-09-15, slightly outdated on nav/FAB — see §8) · `README.md` (marketing + setup) · `git log` (change record).

---

## 1. What CoreGym Is

A bilingual (English / العربية with full RTL) fitness & nutrition app built around three pillars:

1. **AI-assisted food logging** — photo scan, voice, text, and barcode; logging takes seconds.
2. **Real human coaching** — coach marketplace, chat (text/voice/image/PDF), subscriptions, and coach-assigned workouts.
3. **Habit reinforcement** — streaks, smart reminders, leaderboard, progress visualization.

Platforms: Android + iOS (Flutter). Owner: alimohammedassi (Ali Asi). Repo: `github.com/alimohammedassi/coregymali`, branch `main`.

**Business model:** clients subscribe to coaches (Stripe Checkout in-app, or free direct subscribe). In-app signup is **client-only** — coach accounts are created exclusively on the external **Core Dashboard** website (a separate repo; currently `SupabaseConfig.dashboardUrl` points to `http://localhost:3000/signup` with a TODO before release).

---

## 2. Tech Stack

| Layer | Choice |
|---|---|
| App | Flutter ≥3.8 / Dart ^3.8.1, package name in pubspec is `core`, Android applicationId `com.example.coregymali` |
| State | `provider` (app-wide: locale, theme, profile) + `flutter_riverpod` (chat + coach features, clean architecture in `lib/chat/` and `lib/features/coach/`) |
| Backend | Supabase (Postgres + Auth + Storage + Realtime + Edge Functions), project ref `mkrjvrnysuvtokqkyoll` |
| AI | Google Gemini via Supabase Edge Functions (no client-side AI calls) |
| Push | OneSignal 5.5.2 (app id in `lib/supabase/supabase_config.dart`; REST key is an edge-function secret, never in the app) + `flutter_local_notifications` for local reminders |
| Payments | Stripe Checkout via edge functions; deep-link return `coregym://payment/success|cancel` (`app_links`) |
| Health | `health` plugin → steps/burned calories sync |
| Charts | `fl_chart`; icons include a custom pixel-art set (`lib/widgets/pixel_art_icons.dart`) |
| Fonts | `google_fonts`; l10n via `flutter_localizations` + `lib/l10n/` (ar/en) |

---

## 3. Code Map

```
lib/
  main.dart                  app entry — Supabase.init, providers, notification init post-frame
  splashscreen.dart          2.6s brand animation (flight→impact→clover→wordmark) + destination bootstrap
  login_sign_up.dart         AuthWrapper, Login/Signup/ForgotPassword (in-app role is ALWAYS 'client')
  fitness_home_pages.dart    FitnessHomePage — bottom nav shell (IndexedStack + TickerMode)
  profile.dart, progrems.dart, forgetpassword.dart
  screens/                   feature screens (nutrition, workout, food logging, leaderboard, ...)
    workout_tabs/            log_workout_tab, my_program_tab, programs_library_tab
  services/                  app-level services (nutrition, workout, assigned workout, rank,
                             streak, notifications, water reminder, voice/text/scan food log, ...)
  providers/                 locale / profile / theme_mode providers
  chat/                      clean-arch chat: data/domain/presentation (realtime, attachments)
  features/coach/            clean-arch coach feature (marketplace, subscriptions, Stripe, dashboard)
  features/home,health,notifications,splash
  widgets/                   shared widgets (food_log_fab, add_food_sheet, assigned_workout_card, ...)
  theme/                     app_colors, app_semantic_colors, app_text, app_animations
  models/                    nutrition/logging models
  l10n/                      Arabic + English strings
  supabase/                  SupabaseConfig
supabase/
  migrations/                11 SQL migrations (2024-03 → 2026-09)
  functions/                 12 edge functions (see §6)
```

---

## 4. Database (Postgres) — Facts & Rules

**Hard rules that have bitten before:**

- **No Postgres enums anywhere.** All status/role columns are `text` + CHECK constraints.
- `profiles.role` CHECK is `client | coach | user` — the legacy `'user'` value **must stay** in any new CHECK or migration.
- `workout_sessions.muscle_group` CHECK is **lowercase snake_case**; `WorkoutService` has a normalizer and falls back to `full_body` on violation (23514). Keep it in sync when touching workout code.
- `subscriptions`: unique constraint is a **partial unique index** — one active row per client (`WHERE status='active'`), applied live 2026-09-14. Repos are idempotent on 23505 (return the existing active row).
- `nutrition_logs` inserts follow a **strip-and-retry** pattern: on PGRST204/42703, drop unrecognized columns and retry (keeps old edge functions compatible).
- Canonical tables are `reviews` and `subscriptions` — older `coach_*` variants are dead; never write to them.
- Realtime chat relies on a DB trigger (`notify_new_message` → pg_net → `send-chat-push`).

**Canonical table groups:**

- Identity/onboarding: `profiles`, `onboarding`, `user_goals`, `body_measurements`, `coach_onboarding`, `coaches`
- Nutrition: `nutrition_logs` (+8 micronutrients), `daily_summary`, `foods` (~430 items, EN+AR names), `food_scans`/`_items`, `voice_food_logs`/`_items`, `barcode_products`, `weekly_progress`
- Workout: `workout_assignments`, `workout_templates`, `workout_template_exercises`, `workout_sessions`, `workout_sets`, `exercises`, `training_programs`, `user_active_program`, `exercise_progress`, `personal_records`
- Social/coach: `subscriptions`, `subscription_plans`, `subscription_phases`, `reviews`, `coach_content`, `stripe_customers`, `payment_intents`
- Chat/notifications: `conversations`, `messages`, `notifications`, `notification_log`, `notification_preferences`
- Community: `daily_activity`; RPCs: `record_daily_activity`, `get_streak_status`, `get_leaderboard`, `get_user_activity`, `mark_conversation_read`, `unread_count`

**Storage buckets:** `food-images` (Pexels dish photos, 430/430 backfilled), `food-scans`, `chat-voice-notes`, `chat-images`, `chat-files` (signed URLs 1y), `coach-media`, `coach-pdfs`.

**Migrations** (in `supabase/migrations/`): RLS fix, core subscriptions (+alter), created_at on nutrition logs, notification system, chat push trigger + cron, additional nutrients, rank/leaderboard, workout assignments, storage food images, foods seed expansion. **Caveat:** the `reviews` table exists in prod but in NO local migration file.

**Known schema issues (open):** `payment_intents` is missing a client FK (dashboard's doing); `personal_records` view has no RLS; ~18 tables have unverified RLS; Android `allowBackup` not disabled.

**Onboarding math:** Mifflin-St Jeor BMR → TDEE × activity multiplier; goals: weight_loss −500 kcal, muscle_gain +300, floor 1200; protein 2 g/kg, fat 25% kcal ÷ 9, carbs remainder ÷ 4.

---

## 5. AI Subsystem (Gemini) — Constraints That Matter

- 4 edge functions use Gemini: `analyze-food` (photo), `log-food-voice`, `log-food-text`, `lookup-barcode`.
- **Gemini free tier:** 429 at ~20 RPM plus 503 bursts. Edge functions use always-estimate prompts and a 5-attempt retry. **No fallback model.**
- When designing ANY new AI feature: budget for 1–2 calls per user per day with caching — not per-interaction calls — or move to a paid tier first.
- AI-logged meals were broken (fiber/sugar/sodium = 0) because live functions were stale builds from Aug 24/25; all 3 were redeployed 2026-09-20 with micros support and verified E2E.
- Proposed next AI features (owner-approved direction, not yet built): daily/weekly AI insights report, "what should I eat tonight" suggestions from the foods catalog, adaptive calorie goals from weight-vs-intake trends, AI workout generator, voice workout logging, batch micros backfill for the catalog.

---

## 6. Edge Functions (12)

| Function | Purpose |
|---|---|
| `analyze-food` | Gemini photo scan → `food_scans` + `food_scan_items` |
| `log-food-voice` | Voice (m4a) → `voice_food_logs` + items |
| `log-food-text` | Text parse → items (stateless) |
| `lookup-barcode` | Barcode → `barcode_products` + AI estimate |
| `send-notification` | Self-push (welcome, calorie alert) — admin path via x-admin-key |
| `send-chat-push` | Chat push, invoked by DB trigger |
| `send-meal-reminders` | pg_cron `0 6,12,18 * * *` UTC → 8ص/2م/8م Cairo |
| `create-checkout-session` | Stripe Checkout session |
| `get-subscription-status` | Deep-link success verification |
| `stripe-webhook` | Source of truth for paid subscriptions (signature-verified) |
| `fetch-dish-image` | Pexels → `food-images` bucket (server-side only; **503 until `PEXELS_API_KEY` secret is set in the dashboard**) |

**Deployment gotchas:** deploy via Supabase Management API multipart upload with the form field named `file` (singular). Cron→function invocations need `--no-verify-jwt`. Secrets live as edge-function secrets (`ONESIGNAL_REST_API_KEY`, `GEMINI`/Google key, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `PEXELS_API_KEY`).

---

## 7. Notifications Map

| Type | Channel | Trigger | Dedupe |
|---|---|---|---|
| Welcome | OneSignal (edge) | signup / first Google login, +6s | once |
| Meal reminders | OneSignal (edge + pg_cron) | 8ص / 2م / 8م Cairo | per window; skips if any food logged today |
| Water reminders | **Local** (TZ Africa/Cairo) | 8 slots 8→22 every 2h | goal reached → reschedule tomorrow |
| Calorie alert | OneSignal | total ≥ 90% of goal inside `logFood` | once/day via `notification_log` |
| Chat push | OneSignal (DB trigger) | every new message | respects prefs; suppressed while room open |

OneSignal login is tied to Supabase auth state (`external_id` = user id). `notification_log` types: welcome | meal_reminder | water_reminder | calorie_alert | chat.

---

## 8. Navigation & Screens (current state — newer than APP_WORKFLOW.md v1)

- Bottom bar: **Home / Nutrition / Workout / Profile** — Workout is the 4th **visible** tab (since 2026-09-15). Uses `liquid_tab_bar` (opaque tier), themed to tokens; bar **folds to the active pill on scroll-down by design**.
- Pages live in an `IndexedStack` with `TickerMode` on children — required for the perf win of **0 frames at idle** (see §12). Back from any tab → Home.
- A volt **food-log FAB floats above the nav bar on ALL tabs**, opening a custom `PopupRoute` glass sheet (animated backdrop blur, staggered cards: AI Scan / Voice / Text / Barcode / Add Meal). The old `QuickFoodLogHub` on Home was deleted. PopupRoute gotcha: wrap in `Material(transparency)` or text shows yellow underlines.
- Home: header (greeting, streak badge, avatar, bell, chat) → week selector (Fri..Thu) → hero fuel card (calorie ring + macro bars, 2-page swipe; **owner: never merge to one page**) → water/steps cards (replaced the deleted VitalsBar; manual steps entry is gone with it) → meals feed. The assigned-workout card lives **only** on the Workout tab's MyProgramTab; the coach banner lives **only** in Profile.
- Other screens: AssignedWorkoutScreen (ready→active→done flow, set logging + rest countdown), Nutrition tab, food logging screens, LeaderboardScreen (podium top3 + my rank), ClientProfileScreen (35-day heatmap + charts), chat (list + room with realtime + attachments), coach feature screens, OnboardingFlow (5 steps, no name field — gender screen was deleted entirely).

---

## 9. Payments (Stripe + Free Path)

- **Paid:** `create-checkout-session` → external browser Checkout → deep link back → `get-subscription-status` → refresh. Server truth is `stripe-webhook` (checkout.session.completed / invoice.paid / subscription.deleted) which cancels old active rows and writes `subscriptions` + `payment_intents`.
- **Free direct path:** cancel current active row → insert new 30-day active row (idempotent on 23505).
- Subscription status values: `pending | active | cancelled | expired` (text, no enum).

---

## 10. Design System — "Kinetic Obsidian" v2.1 (CANONICAL)

The README still says "Graphite & Soft Volt" — that is **outdated**. Kinetic Obsidian v2.1 (since 2026-09-11) is canonical. All colors via `AppColors` tokens in `lib/theme/app_colors.dart`; **never hardcode colors**.

- **Dark:** olive-graphite surfaces — bg `#121310`, surface `#171814`, card `#1F201B`, text `#ECEEE2`/`#A9ADA0`, border `#2C2D27`. Accent **volt `#D1FC00`**.
- **Light:** fully neutral — `#FAFAFA` / `#FFFFFF` / `#1A1A1A` (the old sage tint is gone). Volt in light mode: **`#8FB800`**.
- **Semantic accents:** calories `#F5A623` (gold family), protein `#EA7A72`, carbs `#E8C468`, fat `#36B37E`, water `#4FD1C5`, steps gold `#E8C468`, fiber `#4FD1C5`, sugars `#9B8AFB`, sodium `#7E9CC9`, lime `#B2D742`.
- Modern tiers: **no glows/gradients** on cards; squircle badges; solid surfaces; pixel-art glyph set for macro icons.
- Theme mode is a provider (system/light/dark) with toggles in Profile.

**Owner rule: NO emojis in the UI. Ever.**

---

## 11. Performance

- Idle rendering is **0 frames** (measured in profile mode): `TickerMode` wraps IndexedStack children; unused pulse controllers and tab-tick `setState`s were removed (2026-09-19). **Do not regress this** — any new always-animating widget on a background tab needs `TickerMode`.
- Startup was optimized 10.3s → 4.7s (query batching, image caching, splash bootstrap).
- Impeller app: `gfxinfo` is useless — use VM timeline for frame analysis.

---

## 12. Testing & Ops (how work is verified here)

**Every change is live-tested on a real device/emulator before being reported done.**

- Devices: prefer the physical **Realme (adb id `37df4276`** — it can vanish mid-session); emulator AVD `New_Device_1` (Android 15+, 16KB pages, slow cold starts 5–35s). Package `com.example.coregymali`.
- Gotchas: use the **full adb path**; **force-stop the app before editing SharedPreferences-backed state**; screenshot between every step; MCP build calls time out at 30s but the build continues — poll, don't restart; `android_logs` is often empty → use pid-filtered logcat; MCP screenshots are downscaled ~0.78× → tap using `android_ui_describe` element bounds, not screenshot pixels.
- Smoke test currently fails even on a clean tree (pre-existing) — not a regression signal.
- Supabase ops: SQL via `npx -y supabase` + Management API SQL endpoint (token in `opencode mcp-auth.json`); `coresupabase` MCP server is configured (project `mkrjvrnysuvtokqkyoll`, **not** read-only). Verify prod schema changes live before assuming.

---

## 13. Working Agreement with the Owner (AI assistants MUST follow)

1. **One task at a time.** Build it, live-test it, then stop for confirmation before the next.
2. **Propose options before implementing** anything non-trivial; let the owner pick.
3. **No `git commit`, no prod SQL without an explicit go-ahead.** The owner runs his own `git push`. Multiple AI sessions work this repo **in parallel — never break or revert their work**; check `git status`/recent changes first.
4. Communication in Egyptian Arabic + English tech terms; but **manual action steps for the owner are written in plain numbered English with exact paths**.
5. Owner likes bar-chart-style prioritization and trade-off framing.
6. Any UI string must exist in **both ar and en** (l10n); Arabic must render correctly in RTL.
7. Disclose any test data written to prod, and clean it up when asked (a few disclosed test rows exist: one banana log, 3 AI-micros rows).

---

## 14. Current State (2026-09-24)

- **Git:** ~60 commits on `main`. There is a **large uncommitted working tree (~87 files)** including: the calories-card classic redesign (2-page swipe), AssignedWorkoutCard restyle, micros page restyle, live home-card refresh (NutritionService static data bus), profile card restyle, food library/filter rework, splash assets + new app icons, and local code for the subscription partial-unique-index fix (already applied live). The owner will commit/push himself.
- **Live prod DB** is ahead of some local migrations (several fixes were applied directly via Management API: subscription partial index, chat embed fix, leaderboard RPCs, workout-assignment dashboard policies).
- **Pending / known issues:** null-name profiles + duplicate RLS policies cleanup; foods catalog micro-nutrient backfill; `PEXELS_API_KEY` secret not yet set; `dashboardUrl` TODO (localhost) before release; RLS unverified on ~18 tables; `allowBackup` flag; AI-feature roadmap (§5) not started.
- **Reference video:** the splash animation replicates the owner's reference video (capsule collision → 4-lobe clover → wordmark, locale-aware «كور جيم»/CoreGym).
