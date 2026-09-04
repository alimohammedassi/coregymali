-- CoreGym notification system — Task 1 (OneSignal infrastructure)
-- Tables for user notification preferences + in-app notification history.
-- All rows are user-scoped; RLS is enabled from day one (service role in
-- Edge Functions bypasses RLS for writing logs / reading prefs server-side).

-- ── Preferences (one row per user; missing row = treated as all-ON) ────────
create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  meal_reminders_enabled boolean not null default true,
  water_reminders_enabled boolean not null default true,
  calorie_alerts_enabled boolean not null default true,
  chat_notifications_enabled boolean not null default true,
  quiet_hours_start time null, -- null = no quiet hours
  quiet_hours_end time null,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

create policy "prefs_select_own" on public.notification_preferences
  for select using (auth.uid() = user_id);
create policy "prefs_insert_own" on public.notification_preferences
  for insert with check (auth.uid() = user_id);
create policy "prefs_update_own" on public.notification_preferences
  for update using (auth.uid() = user_id);

-- ── In-app notification history / inbox ────────────────────────────────────
create table if not exists public.notification_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,              -- welcome | meal_reminder | water_reminder | calorie_alert | chat
  title text not null,
  body text not null,
  data jsonb null,                 -- deep-link payload (conversation_id, etc.)
  sent_at timestamptz not null default now(),
  read_at timestamptz null
);

create index if not exists notification_log_user_recent
  on public.notification_log (user_id, sent_at desc);

alter table public.notification_log enable row level security;

create policy "nlog_select_own" on public.notification_log
  for select using (auth.uid() = user_id);
create policy "nlog_update_own" on public.notification_log
  for update using (auth.uid() = user_id);
-- Inserts are performed by Edge Functions with the service role key
-- (bypasses RLS); users never insert directly.

-- Keep "unread count" cheap: partial index on unread rows only.
create index if not exists notification_log_user_unread
  on public.notification_log (user_id, sent_at desc)
  where read_at is null;
