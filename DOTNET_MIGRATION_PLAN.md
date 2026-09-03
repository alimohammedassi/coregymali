# CoreGym — Supabase → .NET (ASP.NET Core) + MySQL Migration Analysis & Plan

**Date:** 2026-09-01
**Scope:** Full backend inventory of the current Supabase project (`mkrjvrnysuvtokqkyoll`) and the Flutter client's coupling to it, followed by a target architecture, data-migration plan, client-migration plan, and risk/effort assessment. **No production code is generated in this pass.**

Sources examined: `supabase/migrations/*` (4 files), all 7 Edge Functions under `supabase/functions/`, `MIGRATE_TO_SUPABASE.md`, `COREGYM_AGENT.md`, `VOICE_FOOD_LOG_SUPABASE_SETUP.md`, `SESSION_HANDOFF.md`, `README.md`, `HEALTH_INTEGRATION.md`, and every Dart file in `lib/` that touches the Supabase SDK (44 files), plus seed-data, CI, and test/ configuration reconnaissance.

> ⚠️ **Global caveat (read first):** the live Supabase database is the only source of truth for the full schema. The repo contains only 4 migration files; ~25 of the ~31 tables (plus views, RPC functions, and most RLS policies) were created out-of-band via the Supabase dashboard/SQL editor/MCP and are **not version-controlled**. Everything below was reconstructed from (a) committed SQL, (b) the exact columns the Flutter client reads/writes, (c) Edge Function writes, and (d) docs. **Step 0 of execution must be `pg_dump --schema-only` + a policies/functions dump of the live project to confirm.** Column lists marked *reconstructed* are high-confidence (they come from actual client payloads) but may miss columns no code path touches.

---

# Phase 1 — Full Backend Inventory

## 1.1 Database schema

### 1.1.1 Table inventory by feature area

PKs are `uuid DEFAULT gen_random_uuid()` unless noted. `created_at timestamptz DEFAULT now()` is assumed on most tables (confirmed on several). Column lists marked **[confirmed]** come from committed SQL or setup docs; **[reconstructed]** from client/Edge-Function payloads.

#### Identity & profile

| Table | Columns (reconstructed) | Keys / constraints | Notes |
|---|---|---|---|
| `profiles` [confirmed cols: id, email, name, role, avatar_url, age, gender, height_cm, weight_kg, fitness_goal, created_at, updated_at; likely more] | id uuid PK = auth.users.id; | RLS: owner-only select/update | Created by trigger `on_auth_user_created` → `handle_new_user()` (SECURITY DEFINER, `ON CONFLICT (id) DO NOTHING`). `role` ∈ {`user`,`coach`} written by client upserts. Client **upserts** this row after signup (`onConflict: id`) — an RLS-insert policy exists or the upsert relies on the trigger having pre-created the row. |
| `auth.users` (Supabase-managed) | id, email, encrypted_password, raw_user_meta_data (`name`, `role`), email_confirmed_at, last_sign_in_at, created_at | — | Supabase Auth (GoTrue). `role` is stored in user **metadata**, not a DB column. |

#### Onboarding & goals

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `onboarding` [reconstructed] | user_id uuid PK/FK→profiles, age, gender, height_cm, weight_kg, goal, activity_level, target_weight, weekly_workouts, completed bool, updated_at | unique `user_id` (upsert conflict key) | RLS owner-only (confirmed in migration). |
| `user_goals` [reconstructed] | user_id PK/FK, daily_calories int, daily_protein_g int, daily_carbs_g int, daily_fat_g int, target_weight_kg, weekly_workouts, updated_at | unique `user_id` | TDEE/macros computed **client-side** (Mifflin-St Jeor) — logic to move server-side or keep client-side. RLS owner-only (confirmed). |
| `body_measurements` [reconstructed] | id uuid PK, user_id FK, measured_date date, weight_kg, body_fat_pct, muscle_mass, chest_cm, waist_cm, hips_cm, arms_cm, thighs_cm, notes, created_at | unique (`user_id`,`measured_date`) | RLS owner-only (confirmed). Read by coach dashboard too → coach-access gap (see 1.2). |
| `weekly_activity` [legacy] | user_id, week_start date, day_index int, actual_pct, goal_pct, … | — | Only used by dead code (`lib/supabase/stats_service.dart`). RLS confirmed. Decide: drop or migrate. |

#### Nutrition

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `foods` [reconstructed] | id uuid PK, name, name_ar, category, calories, protein_g, carbs_g, fat_g, serving_size_g?, image_url?, is_custom bool, created_by uuid, … | — | Catalog (~319 rows incl. custom). RLS: **public SELECT, authenticated INSERT** (confirmed). Custom foods: `is_custom:true, created_by`. Images backfilled via Pexels (uncommitted script). |
| `nutrition_logs` [reconstructed] | id uuid PK, user_id FK, food_id uuid FK→foods (nullable, only when UUID), food_name text, meal_type (breakfast/lunch/dinner/snack), quantity, serving_unit ('g'), calories, protein_g, carbs_g, fat_g, logged_date date, logged_at timestamptz, created_at timestamptz **added 2026-08-23** | — | Core food diary. RLS owner-only (confirmed). Rows also written *for* users by AI flows client-side. |
| `daily_summary` [reconstructed] | id?, user_id FK, summary_date date, calories_consumed int, protein_g, carbs_g, fat_g (ints), steps, water_ml?, sleep_hours?, mood?, calories_burned?, weight_kg?, updated_at | unique (`user_id`,`summary_date`) | **Client-maintained aggregate**, upserted by 4 independent flows (nutrition, manual stats, measurements, health sync) with partial upserts. RLS owner-only (confirmed). Read by coach dashboard. |
| `barcode_scan_history` [reconstructed] | id, user_id, barcode, product_name?, calories?, …, scanned_at | — | Best-effort insert after a scan saves. SESSION_HANDOFF mentions a `drop_barcode_history_cache_fk` migration → an old FK to `barcode_products` was removed. |
| `barcode_products` [reconstructed] | barcode PK (text), product_name, product_name_ar, brand, serving_size_g, calories, protein_g, carbs_g, fat_g, source ('cache'/'openfoodfacts'/'gemini_estimate'), confidence, lookup_count int, created_at | unique `barcode` | Shared lookup cache; server (Edge Function) writes only. Currently **0 rows in prod** (per SESSION_HANDOFF). |

#### AI food logging (server-written)

| Table | Columns (confirmed via Edge Functions + setup doc) | Keys | Notes |
|---|---|---|---|
| `food_scans` | id uuid PK, user_id FK, image_path text, is_food bool, confidence text (low/medium/high), notes text, created_at | — | Written by `analyze-food`. |
| `food_scan_items` | id uuid PK, scan_id FK→food_scans, name, name_ar, estimated_weight_g, calories, protein_g, carbs_g, fat_g, nutrition_log_id uuid FK→nutrition_logs (nullable; set on user save), created_at | — | Rows linked to diary entries client-side post-save. |
| `voice_food_logs` | id uuid PK, user_id FK, audio_path text, transcript text, is_food bool, confidence, notes, logged_at, created_at | — | Written by `log-food-voice`. Schema confirmed in setup doc. |
| `voice_food_log_items` | id uuid PK, log_id FK→voice_food_logs, name, name_ar, estimated_weight_g, calories, protein_g, carbs_g, fat_g, nutrition_log_id uuid (nullable), created_at | — | Same link-back pattern as scan items. |

#### Workouts

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `exercises` [reconstructed] | id uuid PK, name, name_ar?, muscle_group, secondary_muscles (text[]?), difficulty, equipment, description?, video_id?, image_url?, … | — | ~57 rows, **only in live DB**. Read with `.ilike('muscle_group', …)`. |
| `workout_sessions` [reconstructed] | id uuid PK, user_id FK, muscle_group, session_name, session_date date, started_at timestamptz, ended_at timestamptz, duration_min int, created_at | — | RLS owner-only (confirmed). Read by coach dashboard. |
| `workout_sets` [reconstructed] | id uuid PK, session_id FK, user_id FK, exercise_name, set_number int, reps int, weight_kg, duration_sec int, created_at | — | RLS owner-only (confirmed). |
| `exercise_progress` [reconstructed] | id, user_id FK, exercise_id FK→exercises, session_id FK, session_date date, best_set_weight, best_set_reps, total_volume, one_rm_estimate, created_at | — | Written by log-workout tab; read by profile stats. |
| `personal_records` [reconstructed] | user_id, exercise_name/exercise_id?, best weight/reps/one-rm … | — | README calls it a **view**; client reads `.eq('user_id')`. Confirm live (view vs table). |
| `training_programs` [reconstructed] | id uuid PK, name, name_ar, level (beginner/…), goal (text, ilike-searched), duration_weeks int, description?, weeks/days structure (JSON?), image? | — | ~10 rows, **only in live DB**. |
| `user_active_program` [reconstructed] | id?, user_id PK/FK, program_id FK→training_programs, current_week int, current_day int, started_at?, updated_at | unique `user_id` | Client upserts; read with PostgREST embedded join `*, training_programs(*)`. |
| `workout_logs` [legacy] | user_id, muscle_group, exercise_name, sets_done, reps_done, weight_kg | — | Dead code only. Decide: drop or migrate. |

#### Health & gamification

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `daily_activity` [reconstructed, HEALTH_INTEGRATION.md] | id?, user_id FK, activity_date date, steps int, active_calories_burned, heart_rate_avg, exercise_minutes, source text, synced_at | unique (`user_id`,`activity_date`) | HealthKit/Health Connect sync (30-min client throttle). |
| `streaks` [reconstructed — implied by RPCs] | user_id PK, current_streak, longest_streak, last_activity_date, … | — | Maintained by RPC `record_daily_activity` / read by `get_streak_status`. Logic currently in Postgres — **must be re-implemented** (see 2.5). |

#### Coach marketplace

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `coaches` [reconstructed] | id uuid PK (=coach's user id), user_id?, is_active bool, specialization **text[]**, price_monthly numeric(10,2), rating numeric, bio?, experience_years?, …, created_at | FK→profiles | Marketplace filter: `.contains('specialization',[s])`, `.lte('price_monthly')`, `.gte('rating')`. |
| `coach_onboarding` [reconstructed] | user_id PK/FK, is_completed bool, profile_image_url, certificate_files **text[]**, transformation_images **text[]**, gallery_images **text[]**, max_clients int, price_premium numeric, bio?, … | — | Client reads/writes arrays directly. |
| `coach_content` [reconstructed] | id uuid PK, coach_id FK, type ('pdf'), title?, file_url text, is_public bool, created_at | — | PDFs in public `coach-pdfs` bucket. |
| `reviews` [reconstructed] | id, coach_id FK, client_id FK?, rating int, comment?, created_at | — | Read-only from client today (no write path found). |

#### Subscriptions & billing

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `subscription_plans` [confirmed] | id uuid PK, coach_id FK→profiles, name, price_usd numeric(10,2), duration_days int, max_clients int, created_at | — | ⚠️ Exists in migration but **no client write path and no UI found that creates plans**. Possibly vestigial vs. the `price_monthly`-driven flow. |
| `subscriptions` [confirmed + drift] | Migration schema: id, coach_id FK, client_id FK, plan_id FK, status CHECK('pending','active','paused','expired','cancelled'), payment_status CHECK('unpaid','paid','refunded'), started_at, expires_at, goals, notes, created_at. **Webhook-era columns in live DB:** tier ('standard'/'premium'), stripe_sub_id, start_date, end_date, updated_at | — | **Schema drift is real and live**: the Stripe webhook writes `tier/stripe_sub_id/start_date/end_date`; the migration added `plan_id/payment_status/started_at/expires_at/goals/notes`. Client code reads/updates `status`, `tier`, `start/end_date`. MySQL target should **consolidate** (see 2.2). |
| `subscription_phases` [confirmed] | id, subscription_id FK CASCADE, phase_number int, title, type CHECK('workout','nutrition','combined'), description, duration_weeks int, status CHECK('upcoming','in_progress','completed'), started_at, completed_at, created_at | — | Read-only from client (coach-authored phases UI may be planned). |
| `stripe_customers` [reconstructed] | id?, user_id PK/FK, stripe_customer_id, created_at | unique user_id | Get-or-create in checkout function. |
| `payment_intents` [reconstructed] | id?, client_id FK, coach_id FK, stripe_payment_id, amount numeric, status ('succeeded'), created_at | — | Written only by webhook. |

#### Communication

| Table | Columns | Keys | Notes |
|---|---|---|---|
| `conversations` [reconstructed] | id uuid PK, client_id FK→profiles, coach_id FK→profiles, last_message_at, created_at | — | FK names used for embedded joins: `conversations_client_id_fkey`, `conversations_coach_id_fkey`. Client query: `.or('client_id.eq.$uid,coach_id.eq.$uid')`. |
| `messages` [reconstructed] | id uuid PK, conversation_id FK, sender_id FK→profiles, content text, is_deleted bool, file_url (exists, **unused**), created_at | — | The app's **only Realtime** dependency (INSERT events). Keyset pagination `created_at < anchor`, limit 50. |
| `notifications` [reconstructed] | id, user_id FK (recipient), coach_id FK (actor, used for embedded join `notifications_coach_id_fkey`), type?, title?, body?, is_read bool, created_at | — | Who writes notifications is unclear (no client write path; maybe DB triggers/Edge Functions or nothing yet). Confirm live. |

#### Legacy / dead

`daily_stats`, `weekly_activity`, `workout_logs`, `user_programs` — referenced only by `lib/supabase/` services that have **no UI callers**. Candidate for drop during migration (or migrate-as-is for safety). `COREGYM_AGENT.md` also mentions legacy sync triggers `nutrition_log_sync` / `workout_session_sync` — verify whether they still exist live and whether `daily_stats` is still being auto-maintained.

### 1.1.2 Views & materialized views

| Name | Kind | Used by | Evidence |
|---|---|---|---|
| `weekly_progress` | view (assumed) | `stats_service.getWeeklyProgress()` | select with user_id/summary_date columns |
| `weight_progress` | view (README) — **possibly absent** | none (code comment says it "doesn't exist") | README lists it; `measurements_service.dart` comment contradicts |
| `personal_records` | view or table (README says view) | `workout_service.getPersonalRecords()` | — |

No materialized views found/mentioned anywhere.

### 1.1.3 Database functions & triggers

| Name | Kind | Purpose | Migration implication |
|---|---|---|---|
| `handle_new_user()` + trigger `on_auth_user_created` ON `auth.users` | SECURITY DEFINER trigger | Auto-create `profiles` row on signup | Becomes application logic in the .NET registration flow |
| `record_daily_activity(p_source)` | RPC function | Upsert today's activity + recompute streak; returns row with `current_streak` | Re-implement in C# (transactional) |
| `get_streak_status()` | RPC function | Returns `{current_streak, longest_streak, logged_today, at_risk}` | Re-implement in C# |
| `mark_conversation_read(p_conversation_id, p_user_id)` | RPC function | Set last-read marker for chat | Re-implement as endpoint or derive from `messages` state |
| `unread_count(p_user_id)` | RPC function | Chat unread badge count | Re-implement as endpoint |
| `nutrition_log_sync`, `workout_session_sync` (per COREGYM_AGENT.md) | Legacy triggers (unconfirmed live) | Sync legacy `daily_stats` | Verify live; likely droppable |

### 1.1.4 Postgres → MySQL type mapping

| Postgres type | Where used | MySQL equivalent | Notes |
|---|---|---|---|
| `uuid` + `gen_random_uuid()` | **All PKs/FKs** | `CHAR(36)` (or `BINARY(16)`) | **Recommend `CHAR(36)`** to preserve existing UUIDs verbatim and keep the Flutter models (string ids, regex UUID check in `nutrition_service`) unchanged. Generate in C# with `Guid.CreateVersion7()` (time-ordered, index-friendly). `BINARY(16)` is a later optimization; not worth the conversion risk now. |
| `timestamptz` | created_at, logged_at, started_at… | `DATETIME(6)` + **store UTC always** (connection string `DateTimeKind=Utc`; EF Core value converter) | MySQL TIMESTAMP is 1970–2038-limited → use DATETIME(6). |
| `date` | logged_date, session_date, summary_date, measured_date, activity_date, week_start | `DATE` | Straightforward. |
| `numeric(p,s)` | prices, macros | `DECIMAL(p,s)` | `numeric(10,2)` prices → `DECIMAL(10,2)`; macro floats → `DECIMAL(8,2)` or `DOUBLE` (confirm live precision). |
| `boolean` | is_food, is_custom, is_active, is_read, is_deleted, completed | `TINYINT(1)` (EF Core maps to bool) | — |
| `text` | names, paths, urls, content | `VARCHAR(255/500)` where bounded, `TEXT` otherwise | — |
| `text[]` (arrays) | coaches.specialization, coach_onboarding.certificate_files / transformation_images / gallery_images, possibly exercises.secondary_muscles | `JSON` column | Client uses `.contains('specialization',[s])` → becomes `JSON_CONTAINS` / `JSON_OVERLAPS` in MySQL; keep arrays small. |
| `jsonb` | auth.users.raw_user_meta_data (Supabase-internal) | `JSON` | Only relevant if any app table uses jsonb — none found in client code. |
| CHECK constraints | subscriptions.status, payment_status; subscription_phases.type/status | `ENUM` column **or** CHECK (MySQL 8.0.16+ enforces CHECK) | Prefer MySQL `ENUM` for these small closed sets; or validate in EF. |
| RLS | all user tables | **None** — reimplemented in API layer | See 1.2 / 2.4. |
| Embedded resource joins (`profiles(…)`) | PostgREST feature | Gone — API composes DTOs via joins | Client response shapes change → handled by new DTOs. |

## 1.2 Row Level Security policies

### 1.2.1 Policies documented in the repo

Pattern A — owner-only (SELECT/INSERT/UPDATE/DELETE with `auth.uid() = user_id`), applied in `20240322_fix_rls.sql` to: `onboarding`, `user_goals`, `nutrition_logs`, `workout_sessions`, `workout_sets`, `daily_summary`, `weekly_activity`, `body_measurements`, `user_programs` (legacy). `profiles`: owner-only SELECT/UPDATE (`auth.uid() = id`, **no INSERT policy** → relies on the definer trigger; the client's post-signup upsert implies either a policy added later or an error swallowed today).

Pattern B — catalog: `foods` → `FOR SELECT USING (true)` (public read, incl. anon) + `FOR INSERT WITH CHECK (auth.uid() IS NOT NULL)` (any authenticated user can insert custom foods).

Pattern C — coach/client relational (from `20260419000000_core_subscriptions.sql`):
- `subscription_plans`: coach full access via `coach_id = auth.uid()`.
- `subscriptions`: coach full access via `coach_id = auth.uid()`; client SELECT-only via `client_id = auth.uid()`.
- `subscription_phases`: coach full access via EXISTS-subquery through parent subscription; client SELECT via parent.

Pattern D — `voice_food_logs` / `voice_food_log_items` (setup doc): "fully enabled, owner-only, same pattern as food_scans."

Storage RLS: `voice-food-logs` & `food-scans` private buckets — users may upload/read/delete only inside their own `{user_id}/` folder prefix.

### 1.2.2 Gaps and business logic that MUST move into the API

| # | Finding | Required .NET behavior |
|---|---|---|
| 1 | **No repo SQL exists for RLS on** `coaches`, `coach_onboarding`, `coach_content`, `reviews`, `exercises`, `training_programs`, `user_active_program`, `daily_activity`, `conversations`, `messages`, `notifications`, `streaks`, `barcode_*`, `food_scans*`, `voice_food_logs*` (beyond the doc note), `stripe_customers`, `payment_intents`. SESSION_HANDOFF states coach↔client access is **"not enforced server-side."** | Dump live policies; assume the worst (permissive). Every one of these tables must get explicit authorization rules in the API (see 2.4). |
| 2 | Coach dashboard reads clients' `nutrition_logs`, `workout_sessions`, `body_measurements`, `daily_summary` — under owner-only RLS this should fail today (client may be silently relying on permissive RLS or service-role paths). | Resource-based authorization: coach may read a user's data **iff an active `subscriptions` row links them**. |
| 3 | Conversations/messages: policy must enforce "participant-only" (`.or(client_id, coach_id)`) + message sender check. | Query filter on conversation membership. |
| 4 | `daily_summary`, `user_goals`, `onboarding`, `body_measurements`, `daily_activity`, `user_active_program` are effectively **one-row-per-user** → API should upsert-owner-only and derive `user_id` from the JWT, never trust the body. | Ownership enforced in command handlers. |
| 5 | `foods` public read + authenticated insert of custom foods. | Anonymous/JWT-optional GET endpoint; authenticated POST restricted to `is_custom=true, created_by=caller`. |
| 6 | `barcode_products` is shared, server-written cache. | Write path lives **only** in the barcode endpoint (no user-write). |
| 7 | Notifications: no visible client write path, yet rows exist per-user. Find the writer live (trigger? function? manual?) and re-implement server-side with proper access rules. | TBD after live dump. |

## 1.3 Supabase Auth usage

| Aspect | Current state |
|---|---|
| Sign-in methods | (1) Email/password: `signInWithPassword`; (2) **Google Sign-In via native ID-token flow**: `google_sign_in` package, `GoogleSignIn(serverClientId: '878197831804-50hoh253cbqhugc283bbuo6siujc9b9s.apps.googleusercontent.com')` → `auth.signInWithIdToken(provider: google, idToken, accessToken)` |
| Signup | `signUp(email, password, data: {'name': …, 'role': …})` — role ('user'/'coach') lives in **user metadata**; email confirmation appears enabled-or-not-relevant (no verification UI in app) |
| Session | Default supabase_flutter persistence (SharedPreferences-backed), auto-refresh by SDK; `onAuthStateChange` exposed but **never subscribed**; no `refreshSession`/`setSession` calls |
| Tokens to backend | Flutter passes nothing manually for PostgREST (SDK attaches JWT). Edge Functions receive `Authorization: Bearer <access_token>` and validate via `admin.auth.getUser(token)` |
| Password reset | `resetPasswordForEmail` exists but is **dead code**; the forgot-password UI's OTP step is **mocked** (`Future.delayed`); final reset uses `auth.updateUser(UserAttributes(password:…))` — which requires an already-authenticated session (broken for true forgot-password; another latent bug the migration should fix) |
| Custom claims/roles | None in JWT. Role is in metadata + mirrored into `profiles.role` (client-upserted) |
| DB coupling | `profiles.id = auth.users.id`; trigger `handle_new_user()` on `auth.users`; all user tables FK → `profiles(id)` |

## 1.4 Edge Functions (7)

Common pattern: CORS preflight → `Authorization: Bearer` JWT → `admin.auth.getUser(token)` (service-role client) → work → JSON. Gemini model: **`gemini-3.6-flash`**, `temperature 0.2`, `responseMimeType: application/json`. Secrets: `GEMINI_API_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.

| Function | Trigger / caller | Input | External calls | Output / side effects |
|---|---|---|---|---|
| `analyze-food` | `food_scan_service.dart` | `{imageBase64, mimeType}` | Gemini Vision (inline image data) | `{scan_id, image_path, is_food, confidence, notes, items[]}`; uploads image → **private** `food-scans` bucket `{uid}/{scanId}.jpg`; inserts `food_scans` + `food_scan_items`; distinct error `persist_failed` (500) when analysis OK but save failed |
| `log-food-voice` | `voice_food_log_service.dart` | `{audioBase64, mimeType}` (m4a/aac/mp3/wav/ogg/flac) | Gemini audio (transcribe + analyze in one call — no separate STT) | `{log_id, audio_path, transcript, is_food, confidence, notes, items[]}`; uploads audio → private `voice-food-logs` `{uid}/{logId}.{ext}`; inserts `voice_food_logs` + `voice_food_log_items` |
| `log-food-text` | `text_food_log_service.dart` | `{text}` (≤1000 chars) | Gemini text | Stateless: `{is_food, confidence, notes, items[]}` — **no persistence** (client saves `nutrition_logs` rows itself) |
| `lookup-barcode` | `barcode_lookup_service.dart` | `{barcode, productNameHint?}` (6–14 digits) | (1) `barcode_products` cache read+`lookup_count` bump (fire-and-forget); (2) Open Food Facts API v2 `/product/{code}.json` (8s timeout, custom UA); (3) Gemini text estimate with partial-OFF context | 3-tier: cache → OFF (must have kcal>0 or macros) → `needs_name_hint:true` branch if nothing usable and no hint → Gemini estimate. Upserts cache. Errors: `upstream_unreachable` (502), `analysis_failed` (502) |
| `create-checkout-session` | `stripe_service.dart` | `{coach_id, tier}` | Stripe: customers.create (get-or-create `stripe_customers`), checkout.sessions.create | Price from `coaches.price_monthly` via inline `price_data` (USD, monthly, **no Stripe Price/Product objects**); product name `CoreGym Coach: {name}`; metadata `{client_id, coach_id, tier}`; `success_url: coregym://payment/success?session_id={…}`, `cancel_url: coregym://payment/cancel` → returns `{checkout_url, session_id}` |
| `get-subscription-status` | `stripe_provider.dart` after deep-link return | `{session_id}` | Stripe: checkout.sessions.retrieve | `{status: payment_status, subscription_id, coach_id}` |
| `stripe-webhook` | Stripe (signed; `STRIPE_WEBHOOK_SECRET`) | Stripe events | — | `checkout.session.completed` → cancel client's other active subs + insert active `subscriptions` (tier, stripe_sub_id, start_date) + `payment_intents`; `invoice.payment_succeeded` → extend `end_date`=period_end, set active, record renewal payment; `invoice.payment_failed` → status `expired`; `customer.subscription.deleted` → `cancelled`. **No idempotency guard** (replays can double-cancel/double-insert) |

## 1.5 Storage buckets

| Bucket | Access | Path convention | Contents | Consumers |
|---|---|---|---|---|
| `coach-media` | **Public** (getPublicUrl) | `{uid}/avatar.jpg`, `{uid}/gallery/{uuid}.{ext}`, `{uid}/certs/{ts}_{file}`, `{uid}/transformations/{ts}_{file}` | Avatars, gallery, certs, transformations (images) | Direct client uploads (upsert:true for avatars); URLs stored in `profiles.avatar_url`, `coach_onboarding.*` |
| `coach-pdfs` | **Public** | `{uid}/{uuid}.pdf` | Coach programs (PDF) | Direct client upload; URL in `coach_content.file_url` |
| `food-scans` | **Private** | `{uid}/{scanId}.jpg` | Food photos | Server-only writes (Edge Function); never read back by app today |
| `voice-food-logs` | **Private** | `{uid}/{logId}.m4a` | Voice recordings | Server-only writes; never read back by app today |

Notes: client appends `?t=<ts>` cache-buster to avatar URLs; deletes parse the path back out of the public URL; no signed URLs are used anywhere.

## 1.6 Realtime / subscriptions

Exactly **one** realtime subscription in the whole app:

| Where | Channel | Event | Handling |
|---|---|---|---|
| `chat_providers.dart:322–359` | `chat:{conversationId}` | Postgres INSERT on `public.messages` (client-side filtered by `conversation_id`) | Append (dedupe by id), auto `mark_conversation_read` for foreign messages; unsubscribe on dispose |

No `.stream(` query streams, no broadcast/presence, no notifications channel (badge is poll/lifecycle-based). Legacy docs mention realtime nowhere else.

## 1.7 Third-party integrations

| Integration | Where | Wiring today |
|---|---|---|
| **Google Gemini** | 4 Edge Functions (vision, audio, text, barcode-estimate) | Raw REST `generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=…`; `GEMINI_API_KEY` secret; free-tier quota ~20 req/day **shared** across AI features (per setup doc) |
| **Stripe** | `create-checkout-session`, `get-subscription-status`, `stripe-webhook` | `stripe@14.21.0` (Deno). Checkout mode=subscription with inline `price_data` (no Products/Prices), USD/monthly. Webhook handles 4 event types. No idempotency, no customer portal, no cancel-from-app flow (client "cancel" = direct DB update) |
| **Open Food Facts** | `lookup-barcode` | REST v2 product endpoint, 8s timeout, custom User-Agent `CoreGym - CoreGym Android App - v1.0` |
| **Google Sign-In** | Flutter `google_sign_in` → Supabase `signInWithIdToken` | Web client ID hardcoded in `auth_service.dart:48`; Supabase Auth consumes the ID token |
| **Pexels** (images) | uncommitted `scripts/backfill_food_images.mjs` (missing) | One-off food-image backfill; `PEXELS_API_KEY` placeholder in `scripts/.env` |

## 1.8 Flutter client coupling

Client init: `Supabase.initialize(url, anonKey)` in `main.dart:19-22`; global accessor `lib/services/supabase_client.dart` (imported by 24 files); direct `Supabase.instance.client` in 6 more. **34 files** import `package:supabase_flutter`. Data access is well-centralized: ~15 service/repository files own almost all calls; screens occasionally reach in directly (profile.dart, coach_detail_screen.dart, chat_providers.dart, workout tabs).

### Per-feature coupling summary

| Feature | Tables/views | Auth | Edge functions | Storage | Realtime | RPC |
|---|---|---|---|---|---|---|
| Auth/account | profiles, onboarding, user_goals, body_measurements | signUp/signIn/signInWithIdToken/signOut/updateUser | — | coach-media (avatar) | — | — |
| Nutrition | foods, nutrition_logs, daily_summary, barcode_scan_history | — | lookup-barcode, analyze-food, log-food-text, log-food-voice | — | — | record_daily_activity (via streak service) |
| AI food logging | food_scan_items, voice_food_log_items (link-back updates) | — | analyze-food, log-food-voice, log-food-text | — | — | — |
| Workouts | exercises, workout_sessions, workout_sets, exercise_progress, personal_records, training_programs, user_active_program | — | — | — | — | record_daily_activity, get_streak_status |
| Stats/progress/home | daily_summary, weekly_progress (view), user_goals, profiles | — | — | — | — | get_streak_status |
| Measurements/health | body_measurements, daily_summary, daily_activity | — | — | — | — | — |
| Coach marketplace | coaches, coach_onboarding, coach_content, reviews, profiles (joins) | — | — | coach-media, coach-pdfs | — | — |
| Coach dashboard | subscriptions+joins, daily_summary (clients'), nutrition_logs, workout_sessions, body_measurements | — | — | — | — | — |
| Subscriptions/billing | subscriptions (status/tier/dates), stripe_customers | — | create-checkout-session, get-subscription-status | — | — | — |
| Chat/notifications | conversations, messages, notifications, profiles (joins) | — | — | — | **messages INSERT** | mark_conversation_read, unread_count |

### Key client behaviors the API must reproduce

1. **Partial-upsert merge semantics**: `daily_summary`/`user_goals`/`onboarding`/`body_measurements`/`daily_activity`/`user_active_program` are upserted by multiple flows with sparse payloads (`onConflict: user_id…`). PostgREST upsert **replaces the row with the sent columns merged onto defaults**, not a full replace — the .NET endpoints must accept sparse PATCH-style upserts and merge non-null fields (or the 4 writers will clobber each other's steps/water/calories).
2. **PostgREST embedded joins** (`profiles(name, avatar_url)`, `client:profiles!client_id(…)`, `*, training_programs(*)`) are used by coach repos, chat, notifications, and my-program tab → these become explicit DTO compositions server-side.
3. AI save flows: client inserts `nutrition_logs` rows then **writes back** `food_scan_items.nutrition_log_id` / `voice_food_log_items.nutrition_log_id`.
4. Streak: every food log and workout end calls `record_daily_activity(p_source)`; UI reads `get_streak_status()`; milestone dedupe cached in SharedPreferences.
5. Deep link `core://payment/success|cancel` (manifest scheme is `core`, not `coregym` as comments claim) closes the Stripe loop.
6. Password reset path is broken-by-design today (mock OTP + session-required `updateUser`) — the migration should ship a real reset flow.

### Secrets hygiene (side-findings to address during migration)

- Supabase URL + anon key hardcoded: `lib/supabase/supabase_config.dart` (+ 2 docs + 1 test).
- Google web client ID hardcoded: `lib/supabase/auth_service.dart:48`.
- `scripts/.env` holds a live **service-role key** (gitignored — OK, but rotate after migration).
- `.claude/settings.local.json` (git-**tracked**) contains a plaintext Anthropic API key → **rotate and remove from history**.
- No Stripe price IDs / webhook secrets committed (good); no CI/CD at all.

---

# Phase 2 — Target .NET Architecture Proposal

## 2.1 Solution layout

Recommendation: **Clean Architecture-lite** (4 projects, feature folders inside Application/Infrastructure). Vertical slice was considered; with 1 developer and ~10 features, Clean-lite gives the testability seams (AI services, Stripe, storage) without ceremony.

```
CoreGym.sln
├── src/
│   ├── CoreGym.Api/                 # ASP.NET Core minimal-ish controllers, SignalR hub, middleware
│   │   ├── Controllers/ (V1/)       # Auth, Profiles, Onboarding, Nutrition, Foods, Workouts,
│   │   │                            # Programs, Stats, Measurements, Health, Streaks, Barcode,
│   │   │                            # AiFood, Coach, Subscriptions, Billing, Chat, Notifications, Media
│   │   ├── Hubs/ChatHub.cs
│   │   └── Program.cs               # auth, DI, Serilog, ProblemDetails, rate limiting
│   ├── CoreGym.Application/         # DTOs, validators, service interfaces, authorization handlers,
│   │   │                            # domain services (StreakService, SummaryAggregator, TdeeCalculator)
│   ├── CoreGym.Domain/              # entities + enums (small; EF-managed)
│   └── CoreGym.Infrastructure/      # EF Core (Pomelo MySQL), GeminiClient, OpenFoodFactsClient,
│                                    # StripeService (Stripe.net), BlobStorage (S3/MinIO/Azure), JWT, Identity
└── tests/ (unit + integration via Testcontainers-MySQL)
```

Stack: .NET 8 LTS, EF Core 8 + **Pomelo.EntityFrameworkCore.MySql**, ASP.NET Core Identity, JWT Bearer (`Microsoft.AspNetCore.Authentication.JwtBearer`), Stripe.net, Swashbuckle, Serilog + MySQL sink, HealthChecks (MySQL/Stripe/Gemini). Deploy initially as a single container (Railway/Fly/Render/VPS) + managed MySQL or self-hosted MySQL 8.

## 2.2 Database & EF Core strategy

**Recommendation: EF Core Code-First.** Justification: (a) the live Postgres schema is only partially documented — modeling entities first and generating a clean MySQL schema is safer than reflecting drifted reality into code; (b) a one-off data-migration script maps Postgres rows onto the new model anyway, so the DDL is ours to define; (c) migrations become the version-controlled schema source the project currently lacks. (Database-first scaffolding adds nothing here since the target is MySQL, not the source.)

Key decisions:

| Topic | Decision |
|---|---|
| PKs | Keep **UUIDs as `CHAR(36)`** with the *same values* migrated over. New rows: `Guid.CreateVersion7()`. Avoids every client regex/id assumption breaking and eliminates PK conversion risk. |
| Timestamps | `DATETIME(6)`, UTC-only convention: EF value converter on all `DateTime` properties + `DateTimeKind=Utc` in connection string; audit fields set in `SaveChanges` interceptor. |
| Arrays | `text[]` → `JSON` columns, mapped as `List<string>` via EF JSON value converter (`coach_onboarding.certificate_files`, `transformation_images`, `gallery_images`, `coaches.specialization`). Filtering on specialization: `JSON_OVERLAPS` via raw SQL in the one query that needs it. |
| JSONB | App tables don't need JSON columns (only auth metadata). If a future need arises, MySQL `JSON` + `JsonDocument` mapping. |
| Enums | Status/type CHECK constraints → C# enums stored as **strings** (keeps DB diffable and matches existing `text` values exactly: 'active', 'cancelled', 'standard'…). |
| Upserts | Implement sparse **merge-upsert** in a reusable handler: `INSERT … ON DUPLICATE KEY UPDATE col = VALUES(col)`-style but only for non-null DTO fields (explicit column list built per request) — reproduces PostgREST partial-upsert semantics for `daily_summary`, `user_goals`, `onboarding`, `body_measurements`, `daily_activity`, `user_active_program`. |
| Views | Recreate `weekly_progress` as a MySQL view (or an EF LINQ projection — prefer **LINQ projection**, one less DB artifact). `personal_records`: implement as a query/service (it aggregates best sets); confirm source definition first. |
| Subscriptions table | **Consolidate the drift**: one canonical table — `id, coach_id, client_id, plan_id (nullable), tier ENUM('standard','premium'), status, payment_status, stripe_subscription_id, started_at, expires_at, end_date, goals, notes, created_at, updated_at`. Map legacy `start_date/end_date` and `started_at/expires_at` onto the canonical pair in the ETL. |
| Indexes | Add what PostgREST queries imply: `(user_id, logged_date)` on nutrition_logs, `(user_id, summary_date)` on daily_summary, `(conversation_id, created_at)` on messages, `(coach_id, status)` on subscriptions, `(user_id, activity_date)`, `(user_id, measured_date)`, FULLTEXT or LIKE-prefix index on foods(name, name_ar) for search. |

## 2.3 Auth — ASP.NET Core Identity + JWT

| Concern | Design |
|---|---|
| Users | ASP.NET Core Identity `IdentityUser` with **the same GUID ids as `auth.users`** → all FK values survive. |
| Passwords | Custom `IPasswordHasher<IdentityUser>`: if stored hash starts with `$2a$/$2b$` (bcrypt, GoTrue's format), verify with bcrypt and **rehash to Identity PBKDF2 lazily on next successful login**; new users hash normally. Requires exporting `auth.users.encrypted_password` (Admin API returns it with service role). **Fallback** (if hashes can't be exported/verified at acceptable effort): force password-reset emails on first login. |
| JWT | Access token (15–60 min) + rotating refresh token (30–90 d, stored hashed in `refresh_tokens` table, revocable). Standard `sub` = user id; `role` claim from `profiles.role`. |
| Google Sign-In | Keep `google_sign_in` in Flutter → POST `/api/v1/auth/google {idToken}` → validate signature + `aud == 878197831804-…` + email verified (Google.Apis.Auth) → find/create Identity user (link by email) → issue app JWT. Same UX as today; no Supabase redirect involved. |
| Forgot password | Fix the current broken flow: server-issued reset (email with time-limited token, `POST /auth/forgot-password`, `POST /auth/reset-password`). Requires SMTP (SendGrid/SES) — **new dependency** for the backend. |
| Email confirmation | Decide: keep optional (matches today's apparent behavior) initially; enable later once SMTP exists. |
| Claims | `sub`, `email`, `role`, `name`. `profiles.role` remains source of truth (meta-data mirror dies with Supabase). |

## 2.4 RLS → API authorization mapping

Mechanisms: **(1)** EF Core global query filters (`HasQueryFilter(e => e.UserId == _currentUser.Id)`) for simple owner tables; **(2)** explicit `userId` derivation from JWT in command handlers (never from body); **(3)** resource-based authorization handlers (`IAuthorizationHandler`) for coach↔client and conversation membership; **(4)** anonymous endpoints + DB-side read-only for the public catalog.

| Supabase policy | .NET enforcement |
|---|---|
| Owner-only CRUD: onboarding, user_goals, nutrition_logs, workout_sessions, workout_sets, daily_summary, body_measurements, daily_activity, user_active_program, food_scans/scan_items, voice_food_logs/items, streaks | Global query filter `UserId == current` + server-set `UserId` on writes |
| profiles: read/update own | `GET /me` composition endpoint; `PATCH /me`; id-from-JWT only |
| foods: public read / authed insert | `[AllowAnonymous] GET`; `POST` requires auth and forces `IsCustom=true, CreatedBy=caller` |
| exercises, training_programs: (effectively public catalog) | `[AllowAnonymous] GET` (or authed), no writes exposed (admin/seed only) |
| subscriptions: coach full / client read | Resource handler: coach claim on `CoachId`; client claim on `ClientId` (read-only role for client) |
| subscription_phases: via parent | Handler resolves parent subscription then applies same rule |
| coach dashboard reads client data (currently unenforced!) | **New explicit policy**: `CoachOfClientRequirement` → passes iff an active subscription row (coach_id, client_id) exists; applied to the "coach read client data" endpoints |
| conversations/messages: participant-only | Query filter on participation OR (`client_id == uid OR coach_id == uid`); message send validated against membership |
| notifications: recipient-only | Owner filter on `user_id` |
| barcode_products: shared cache | No user-facing writes; server-managed |
| Storage: private buckets `{uid}/…` | Storage service verifies path prefix == caller id before signing URLs (private) |

## 2.5 Edge Functions → .NET replacements

| Edge Function | New endpoint(s) | Notes |
|---|---|---|
| `analyze-food` | `POST /api/v1/ai/food/scan` (multipart or base64 JSON) | `GeminiClient` (raw HttpClient or official Google AI SDK) same prompt/model/temperature + JSON schema validation; upload image to blob storage **private** container; persist `food_scans`+items; return same response shape (ids) |
| `log-food-voice` | `POST /api/v1/ai/food/voice` (multipart; server accepts raw audio better than base64 JSON) | Same Gemini audio call; same persistence + response shape |
| `log-food-text` | `POST /api/v1/ai/food/text` | Stateless; same response shape |
| `lookup-barcode` | `GET|POST /api/v1/barcode/lookup` | Same 3-tier (cache → OFF → Gemini), same error contract (`needs_name_hint`, `upstream_unreachable`, `analysis_failed`); `lookup_count` bump fire-and-forget; upsert cache. Add HttpClient resilience (Polly) |
| `create-checkout-session` | `POST /api/v1/billing/checkout-session` | Stripe.net; keep inline `price_data` from `coaches.price_monthly` (no need to create Stripe Products); same metadata + deep-link URLs |
| `get-subscription-status` | `POST /api/v1/billing/session-status` | Retrieve session; same response |
| `stripe-webhook` | `POST /api/v1/billing/webhook` | Signature verification via Stripe.net; **add idempotency** (`processed_events` table keyed on event id); keep the 4 event behaviors; write to the consolidated subscriptions schema |
| `handle_new_user` trigger | Inside `AuthService.Register` + Google exchange | Create `profiles` row transactionally with user creation |
| `record_daily_activity` / `get_streak_status` RPCs | `StreakService` (Application) + `POST /api/v1/streaks/activity`, `GET /api/v1/streaks` | Port streak algorithm to C#; **extract and port current streak state** during ETL |
| `mark_conversation_read` / `unread_count` | `POST /conversations/{id}/read`, `GET /conversations/unread-count` | Implement via last-read marker column or message-state query |

## 2.6 File storage

Recommendation: **S3-compatible object storage** — Cloudflare R2 (zero egress cost, ideal for an app serving images) or AWS S3; MinIO if fully self-hosted. Azure Blob equally fine if that's the team's cloud.

| Supabase bucket | Target | Access model |
|---|---|---|
| `coach-media` (public) | `coach-media` container w/ public CDN base URL | Keep **public-read + URL-in-DB** pattern to avoid touching every stored URL; base URL configurable per environment |
| `coach-pdfs` (public) | `coach-pdfs` public container | Same |
| `food-scans` (private) | `food-scans` private container | Server writes only; presigned GET (15-min) exposed only if a future UI needs to show past scans |
| `voice-food-logs` (private) | `voice-food-logs` private container | Same |

API: `POST /api/v1/media/upload` (multipart, scoped by folder type: avatar/gallery/cert/transformation/pdf) → server enforces `{uid}/…` prefix, returns URL; `DELETE /api/v1/media` by path. Uploads move from client-direct-to-bucket to client→API→blob (files are small; simpler than presigned PUT initially — presigned PUT can be added later for large media).

## 2.7 Realtime replacement

Only chat needs push. **SignalR hub** (`/hubs/chat`) with JWT auth:
- Client joins group `conversation:{id}` after membership check; server broadcasts `MessageCreated` on insert.
- Notifications can ride the same hub later (`NotificationCreated`) — currently poll-based, no change needed day one.
- Fallback/polling: the chat repository already refreshes on send; SignalR failure degrades gracefully to pull-on-focus (same as notifications today).

## 2.8 API design (v1)

Conventions: REST, JSON, `/api/v1`, ProblemDetails errors, cursor pagination (`?before=<created_at>`) matching today's keyset style, snake_case JSON (matches existing Dart models via `json_serializable` naming — minimizes model churn). Versioning via URL segment.

| Area | Endpoints |
|---|---|
| Auth | `POST /auth/register` · `POST /auth/login` · `POST /auth/google` · `POST /auth/refresh` · `POST /auth/forgot-password` · `POST /auth/reset-password` · `POST /auth/logout` |
| Profile | `GET /me` · `PATCH /me` · `GET /profiles/{id}` (coach-visible fields) |
| Onboarding/Goals | `GET|PUT /onboarding` (merge-upsert) · `GET|PUT /goals` · `POST /onboarding/complete` (computes TDEE server-side) |
| Foods | `GET /foods/search?q&category&limit` · `POST /foods` (custom only) |
| Nutrition | `POST /nutrition/logs` · `GET /nutrition/logs?date` · `PATCH /nutrition/logs/{id}` · `DELETE /nutrition/logs/{id}` · `GET /nutrition/summary?date` · `PUT /nutrition/summary` (merge-upsert) |
| AI food | `POST /ai/food/scan` · `POST /ai/food/voice` · `POST /ai/food/text` · `POST /ai/food/save-scan` (bulk log insert + item link-back in one call — better than current 2-step) |
| Barcode | `POST /barcode/lookup` · `POST /barcode/history` · `GET /barcode/history` |
| Workouts | `POST /workouts/sessions` · `PATCH /workouts/sessions/{id}/end` · `GET /workouts/sessions?date` · `POST /workouts/sessions/{id}/sets` · `GET /workouts/sessions/{id}/sets` · `GET /workouts/personal-records` · `POST /workouts/progress` (exercise_progress) |
| Exercises/Programs | `GET /exercises?muscleGroup` · `GET /programs?level&goal` · `GET /programs/active` · `PUT /programs/active` |
| Streaks/Stats | `POST /streaks/activity` · `GET /streaks` · `GET /stats/weekly` · `GET /stats/month` (profile month aggregation currently done client-side via 5 calls → compose server-side) |
| Measurements/Health | `PUT /measurements` · `GET /measurements` · `GET /measurements/latest` · `PUT /health/activity` (merge-upsert) · `GET /health/activity?from` |
| Coach — marketplace | `GET /coaches?specialization&maxPrice&minRating` · `GET /coaches/{id}` (with gallery, pdfs, reviews) |
| Coach — profile/media | `GET|PUT /coach/profile` · `POST /coach/media` · `DELETE /coach/media` · `GET /coach/content` · `POST /coach/content` · `DELETE /coach/content/{id}` |
| Coach — dashboard | `GET /coach/dashboard` (active subs + today's client summaries composed server-side) · `GET /coach/clients/{userId}` (guarded by active-subscription policy) |
| Subscriptions | `GET /subscriptions/active` · `GET /coach/subscriptions` (with client/plan/phase joins) · `POST /subscriptions/{id}/cancel` · `POST|GET /subscriptions/{id}/phases` |
| Billing | `POST /billing/checkout-session` · `POST /billing/session-status` · `POST /billing/webhook` (anonymous, signature-verified) |
| Chat | `GET /conversations` · `POST /conversations` · `GET /conversations/{id}/messages?before` · `POST /conversations/{id}/messages` · `POST /conversations/{id}/read` · `GET /conversations/unread-count` · SignalR `/hubs/chat` |
| Notifications | `GET /notifications?before` · `POST /notifications/{id}/read` · `POST /notifications/read-all` · `GET /notifications/unread-count` |
| Media | `POST /media/upload` · `DELETE /media` |

---

# Phase 3 — Data Migration Plan

## 3.1 Tooling

**Recommendation: custom ETL scripts (C# or Python) + `mysqldump`-free bulk load.** Rationale: pgloader migrates *to* Postgres, not from it; Supabase-hosted Postgres allows `pg_dump`/COPY access, so export per-table to CSV/NDJSON (`psql \copy` or `pg_dump --data-only --column-inserts` for small tables), transform (type casts, array → JSON, timezone normalization to UTC, subscription column consolidation), and bulk-load with MySQL `LOAD DATA` / MySqlBulkLoader into the EF-generated schema. Small dataset (low thousands of rows estimated) — no need for CDC tooling. Auth users export via **Supabase Admin API** (`GET /auth/v1/admin/users` with service key: id, email, encrypted_password, raw_user_meta_data, timestamps).

## 3.2 Migration order (FK-respecting)

1. **Users**: auth.users → Identity users (+ bcrypt hashes, metadata → `profiles.name/role` snapshot)
2. `profiles`
3. Catalogs: `foods`, `exercises`, `training_programs`
4. Per-user singletons: `onboarding`, `user_goals`, `user_active_program`, `streaks` (derive/seed state)
5. `body_measurements`, `daily_activity`, `daily_summary`
6. `nutrition_logs`
7. `food_scans` → `food_scan_items` → `voice_food_logs` → `voice_food_log_items` (preserve ids incl. nullable `nutrition_log_id` links)
8. `workout_sessions` → `workout_sets` → `exercise_progress` → (`personal_records` recomputed if view)
9. `coaches` → `coach_onboarding` → `coach_content` → `reviews`
10. `subscription_plans` → `subscriptions` (consolidated) → `subscription_phases`
11. `stripe_customers` → `payment_intents`
12. `conversations` → `messages`
13. `notifications`
14. `barcode_products`, `barcode_scan_history`
15. Legacy (`daily_stats`, `weekly_activity`, `workout_logs`, `user_programs`): migrate as-is **or** archive-and-drop (recommend archive table + drop — nothing reads them)

## 3.3 Seeded datasets

| Dataset | Location today | Risk | Handling |
|---|---|---|---|
| ~319 foods (incl. Pexels image URLs) | **Live DB only** — uncommitted backfill scripts; no local copy | **Highest data-loss risk of the whole project** | Export FIRST, before any other work; store as version-controlled SQL/CSV in repo (`db/seeds/`) going forward |
| ~57 exercises | Live DB only (local 55-entry `exercise_database.dart` is a separate, unsynced dataset used only by AI Smart Trainer) | High | Export to seeds; do **not** attempt to reconcile with local Dart list in this migration |
| ~10 training programs | Live DB only | High | Export to seeds |
| 8 popular-food presets, 9 search chips | Hardcoded in Dart widgets | None | Unaffected |

## 3.4 Validation & reconciliation

1. **Row counts** per table (source vs target) with a written manifest; investigate any delta.
2. **Checksums**: per table, `MD5(ORDER BY id)` over canonicalized row JSON (stable column order, normalized decimals/dates) — catches silent truncation/casting issues, esp. timestamps and numerics.
3. **FK orphan sweep** on target (zero orphans expected).
4. **Spot checks** (scripted): for 5 random users — today's nutrition log list, streak status, active program, chat thread, coach dashboard numbers rendered identically from MySQL via the new API vs Supabase directly.
5. **Auth dry-run**: bcrypt-verify 10 sampled password hashes against the new hasher before cutover; Google sign-in exchange end-to-end on staging.
6. **Binary objects**: count storage objects per bucket (4 buckets) vs objects referenced in DB (`food_scans.image_path`, `voice_food_logs.audio_path`, avatar/gallery/content URLs) — migrate blobs first (they're independent of FK order), verify with ETag/size manifest.

## 3.5 Cutover, downtime, rollback

**Recommendation: big-bang cutover with a short maintenance window** (this app's scale and single-dev team make dual-write/parallel-run cost > benefit; the client is already structured for a clean backend swap behind a flag). Parallel *verification* (read-only comparison, §3.4 #4) still happens pre-cutover.

1. **T-7d**: feature-freeze; ETL dry-run to staging; validation report green.
2. **T-1d**: publish app release with backend toggle (§4.4) to stores *ahead* of cutover, still pointed at Supabase.
3. **T-0 (window, est. 1–3h)**: enable maintenance banner → final export/diff (incremental since dry-run) → load MySQL → validation suite → flip Supabase project to read-only/suspend → store blobs pre-migrated → smoke test on staging → point production toggle to .NET.
4. **Rollback plan**: toggle points back to Supabase (kept intact, read-only). Any writes that reached MySQL during a failed window are replayed to Supabase by a reverse-diff script (they'll be few and are captured by an audit `created_at > cutover` query) — or, simpler, declare the window failed and re-run cutover later (no user writes lost because Supabase was only suspended, not deleted). Keep Supabase alive read-only ≥ 30 days.
5. Keep `barcode_products`, storage objects, and old JWTs in mind: all sessions are invalidated at cutover (users re-login once — acceptable; communicate in release notes).

---

# Phase 4 — Flutter Client Migration Plan

## 4.1 Call-site replacement map

The good news: ~90% of Supabase calls flow through **15 service/repository files**. Replace their internals; screens stay untouched.

| Flutter file(s) | Today | Becomes |
|---|---|---|
| `lib/services/supabase_client.dart`, `lib/supabase/*` | Supabase client + auth/profile/stats services | `ApiClient` (dio) + `AuthService` (token storage, refresh interceptor), `ProfileApi`, dead `stats_service.dart` deleted |
| `lib/services/nutrition_service.dart` | foods/log CRUD, summary upsert | `NutritionApi` (DTOs already implicit) |
| `lib/services/stats_service.dart`, `streak_service.dart` | daily_summary, weekly view, RPCs | `StatsApi`, `StreakApi` (milestone SharedPreferences logic stays) |
| `lib/services/workout_service.dart`, workout tabs | sessions/sets/progress/programs | `WorkoutApi`, `ProgramsApi` |
| `lib/services/onboarding_service.dart`, `measurements_service.dart` | onboarding/goals/measurements | `OnboardingApi`, `MeasurementsApi` |
| `lib/services/food_scan_service.dart`, `text_food_log_service.dart`, `voice_food_log_service.dart`, `barcode_lookup_service.dart` | 4 Edge Function invokes | 4 dio calls to `/ai/food/*`, `/barcode/lookup` |
| `lib/features/coach/data/**` (5 repos + stripe_service + coach_media_service) | PostgREST queries + edge fn + storage | `CoachApi`, `DashboardApi`, `SubscriptionApi`, `BillingApi`, `MediaApi` |
| `lib/chat/data/repositories/*`, `chat_providers.dart` | PostgREST + RPC + **Realtime channel** | `ChatApi`, `NotificationsApi` + SignalR client (`web_socket_channel` / official SignalR client) replacing the channel — keep the same notifier interfaces |
| `lib/features/health/data/health_service.dart` | daily_activity/summary upserts | `HealthApi` |
| Direct screen calls: `login_sign_up.dart`, `profile.dart`, `splashscreen.dart`, `profile_provider.dart`, `coach_detail_screen.dart`, `coach_marketplace_screen.dart`, `fitness_home_pages.dart`, `forgetpassword.dart` | inline `.from()` + auth reads | Route through the APIs above; `forgetpassword` OTP mock → real reset flow |
| `core://payment` deep link (app_links) | unchanged | unchanged (same URL contract in new billing endpoints) |

## 4.2 Auth flow changes

- Token storage: **flutter_secure_storage** (access + refresh). dio interceptor: attach Bearer; on 401 → refresh once → retry; on refresh failure → logout to splash.
- Google: same `google_sign_in` UX; pass `idToken` to `/auth/google` (web client ID stays the same — no Google Cloud console change).
- Session bootstrap in `splashscreen.dart`: replace `supabase.auth.currentUser` with local token presence + `GET /me` validation.
- Signup still passes name/role → now part of `POST /auth/register` body; server creates profile row.
- Real password reset finally works (server email flow) — remove the mocked OTP path.

## 4.3 Cutover sequencing (low → high risk)

1. **Catalog reads** (foods, exercises, programs) — stateless, instantly verifiable.
2. **Workouts + nutrition writes** — highest write volume but self-contained, per-user.
3. **Profile/onboarding/goals/measurements/health** — merge-upsert semantics verified here.
4. **Streaks + stats** — algorithm port validated against Supabase outputs.
5. **AI features + barcode** — same Gemini/OFF calls; latency parity easy to measure.
6. **Chat + notifications** — SignalR swap; needs live two-device testing.
7. **Coach marketplace/dashboard** — exercises the new cross-user authorization policies.
8. **Stripe billing** — last: needs webhook re-verification in Stripe dashboard, a sandbox end-to-end purchase, and the idempotency rewrite. Test with Stripe test mode + one live $0/mo-ish real transaction before enabling.

## 4.4 Side-by-side toggle strategy

- Single source: `const String kApiBaseUrl = String.fromEnvironment('BACKEND_BASE_URL')` + `--dart-define` flavors (`supabase` / `dotnet`).
- Because services are centralized, implement **two implementations behind the existing service interfaces** only where cutover order demands it (e.g., `FoodsRepository` backed by Supabase *or* ApiClient). Simpler alternative given the sequencing: a global `Backend` enum checked in the 15 service files — feature cutover flips service-by-service flags from a remote map (add `remote_config`-style JSON served by the new API or Firebase Remote Config if staying minimal).
- Keep both implementations until step 8 of §4.3 passes in production for 2 weeks; then delete Supabase code paths (`supabase_flutter` out of pubspec).

---

# Phase 5 — Risk Assessment & Effort Estimate

## 5.1 Highest-risk areas

| # | Risk | Why | Mitigation |
|---|---|---|---|
| 1 | **RLS → API authorization translation** (esp. coach↔client reads that are *unprotected today*; conversations; catalog) | Silent privilege escalation or silent feature breakage; live policy set is unverified | Dump live policies day 1; build the authorization matrix (2.4) with integration tests per rule; default-deny |
| 2 | **Password/auth migration** | bcrypt→PBKDF2 import is subtle; botched = every user locked out | Custom hasher + lazy rehash; verify 10 sampled hashes in staging; force-reset fallback; keep Supabase login alive for 30 days as fallback |
| 3 | **Stripe webhook correctness + `subscriptions` schema drift** | Two generations of columns live in one table; webhook has no idempotency; Stripe dashboard must repoint | Consolidated schema + event-id dedupe table; full sandbox E2E (purchase→renew→fail→cancel); keep old webhook running until new one proven |
| 4 | **Partial-upsert semantics** (daily_summary multi-writer) | PostgREST upsert ≠ naive ON DUPLICATE KEY; steps/water/calories clobbering | Merge-upsert handler + tests covering all 4 writer flows |
| 5 | **Seed data only in live DB** (foods/images, exercises, programs) | One bad export = permanent content loss | Export + commit to repo *first*; checksum manifest |
| 6 | **AI latency/cost** | Same Gemini calls from .NET — parity expected; real risk is *no* change in free-tier ceiling (20 req/day shared) while user base grows; base64 payloads through the API vs Edge Function are equivalent | Keep payload format; add caching for barcode results (already designed); consider paid tier later |
| 7 | **Chat realtime swap** | Only push feature; SignalR on mobile + backgrounding edge cases | Keep pull-on-focus fallback; two-device test matrix |
| 8 | **Storage URL/permission change** | Public URL pattern preserved → low risk; private buckets server-only → none; risk is misconfigured CDN caching of avatars | Keep `?t=` cache-buster convention; verify `Cache-Control` headers |
| 9 | **Session invalidation at cutover** | All users re-login once | Communicate in release notes; keep window short |

## 5.2 Effort estimate (single experienced full-stack dev, working days)

| Phase / workstream | Days |
|---|---|
| P0 Live-schema dump, policy dump, seed export & commit, blob inventory | 1–2 |
| .NET skeleton: solution, EF model, MySQL schema, CI, logging, health checks | 3 |
| Auth: Identity + JWT + refresh + Google exchange + reset flow + bcrypt import | 4–5 |
| Core REST (profile/onboarding/goals/nutrition/summary merge-upsert/workouts/programs/measurements/health/streaks/stats) | 6–8 |
| AI + barcode services (Gemini client, OFF client, persistence, storage integration) | 3–4 |
| Coach domain + subscriptions + Stripe (checkout, status, webhook + idempotency) | 5–6 |
| Chat + notifications + SignalR | 3–4 |
| Media/storage service + bucket migration | 1–2 |
| ETL scripts + staging dry-runs + validation suite | 3–4 |
| Flutter migration (services, auth, toggle, SignalR client) + QA across both platforms | 6–8 |
| Cutover + hypercare fixes + Supabase decommission prep | 2–3 |
| **Total** | **≈ 37–49 days (8–10 calendar weeks)** |

## 5.3 Recommended execution checklist

1. [ ] `pg_dump --schema-only` + policies + functions + triggers dump of live Supabase; diff vs this document's reconstruction; reconcile.
2. [ ] Export & commit seeds (foods, exercises, training_programs) + blob object manifest; rotate the leaked Anthropic key & service-role key.
3. [ ] Provision MySQL 8 + repo scaffolding; EF Core model → initial migration (consolidated subscriptions table included).
4. [ ] Auth stack (register/login/JWT/refresh/Google/reset) + bcrypt import spike against 10 real hashes.
5. [ ] Core CRUD endpoints in dependency order (catalog → per-user tables) with integration tests incl. merge-upsert semantics.
6. [ ] Streak service port (parity-tested against RPC outputs).
7. [ ] AI + barcode endpoints (contract-identical to Edge Functions).
8. [ ] Storage service + blob copy (4 buckets) + public URL parity check.
9. [ ] Coach + chat + notifications + SignalR.
10. [ ] Stripe: checkout/status/webhook with idempotency; sandbox E2E.
11. [ ] ETL to staging + full validation suite green (counts, checksums, orphans, auth dry-run, spot checks).
12. [ ] Flutter: API client + auth swap + service re-implementations behind toggle; QA both backends.
13. [ ] Store release with toggle (still → Supabase).
14. [ ] Cutover window (§3.5) → flip toggle → hypercare.
15. [ ] Two weeks parallel-read-only → delete Supabase code paths, decommission, final key rotation.

---

# Appendix A — Assumptions & information gaps (confirm during Phase-0 dump)

| # | Assumption made | What to confirm |
|---|---|---|
| 1 | Column lists marked *reconstructed* are complete | `pg_dump --schema-only`; look for columns no code path touches |
| 2 | Live RLS exists only as documented + possibly permissive extras | `pg_policies` dump; especially `coaches`, `conversations`, `messages`, `notifications`, `daily_activity`, `exercises`, `training_programs` |
| 3 | `personal_records` is a view; `weight_progress` may not exist | `pg_views` / `pg_matviews` |
| 4 | Legacy triggers `nutrition_log_sync`, `workout_session_sync` may still be active | `pg_trigger` |
| 5 | GoTrue stores bcrypt password hashes (`$2a$…`) and the Admin API exposes `encrypted_password` | Sample `GET /auth/v1/admin/users` response |
| 6 | Email confirmation is effectively optional in current auth config | Supabase Auth settings |
| 7 | Row volume is small (< ~100k rows total) → big-bang viable | Live counts per table |
| 8 | No writes occur to `notifications` from the current backend (writer unknown) | Find the writer (function/trigger/manual) |
| 9 | `subscription_plans` is vestigial (no client/UI write path) | Check dashboard data + whether phases UI is planned |
| 10 | `barcode_products` empty in prod (per SESSION_HANDOFF) and `GEMINI_API_KEY` secret may be unset on the barcode function | Function logs / secrets config |
| 11 | Storage objects = only those referenced in DB + food-scan images/voice audio | Bucket listings vs DB paths |
| 12 | One manifest scheme (`core://payment`) is the only deep link in play | Manifest + app_links handler |
| 13 | Postgres extension deps (pgcrypto for gen_random_uuid) vanish with the migration | N/A — just noting the DDL responsibility moves to EF |

# Appendix B — Immediate hygiene actions (before any migration work)

1. Rotate the Anthropic API key committed in `.claude/settings.local.json` and purge the file from git history.
2. Rotate the Supabase service-role key stored in `scripts/.env` (gitignored, but handle carefully) — do this *after* final data export.
3. Move the Supabase URL/anon key and Google client ID out of source into `--dart-define` / env config (low urgency — anon key is public by design, but config hygiene matters for the new backend).
4. Version-control the seed data and restore/commit `backfill_food_images.mjs` so the foods dataset is reproducible.
5. Add a minimal CI workflow (flutter analyze + dotnet test) once the .NET repo exists.
