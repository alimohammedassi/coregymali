-- ============================================================================
-- Gym Attendance (Phase 1) — gyms + gym_attendance tables.
--
-- `gyms`            — one row per configured gym; multiple inserts allowed
--                     over time, newest row (created_at desc) is the active
--                     gym. RLS scopes every operation to auth.uid().
-- `gym_attendance`  — one visit per user/gym/day (unique index below); rows
--                     are written by the geofence flow (Phase 2/3) with
--                     `source` recording how the visit was detected.
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.gyms (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  latitude   double precision not null,
  longitude  double precision not null,
  radius_m   int not null default 120,
  created_at timestamptz not null default now()
);

create table if not exists public.gym_attendance (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  gym_id             uuid not null references public.gyms(id),
  date               date not null,
  check_in_time      timestamptz not null,
  check_out_time     timestamptz,
  duration_minutes   int,
  activity_confirmed boolean default false,
  source             text not null check (source in ('geofence','manual','activity_backup')),
  created_at         timestamptz not null default now(),
  unique (user_id, gym_id, date)
);

alter table public.gyms enable row level security;
alter table public.gym_attendance enable row level security;

create policy "gyms_select_own" on public.gyms
  for select using (auth.uid() = user_id);
create policy "gyms_insert_own" on public.gyms
  for insert with check (auth.uid() = user_id);
create policy "gyms_update_own" on public.gyms
  for update using (auth.uid() = user_id);
create policy "gyms_delete_own" on public.gyms
  for delete using (auth.uid() = user_id);

create policy "gym_attendance_select_own" on public.gym_attendance
  for select using (auth.uid() = user_id);
create policy "gym_attendance_insert_own" on public.gym_attendance
  for insert with check (auth.uid() = user_id);
create policy "gym_attendance_update_own" on public.gym_attendance
  for update using (auth.uid() = user_id);
create policy "gym_attendance_delete_own" on public.gym_attendance
  for delete using (auth.uid() = user_id);

create index if not exists gym_attendance_user_date_idx
  on public.gym_attendance (user_id, date desc);

-- ============================================================================
-- Rollback (documented only — do not execute as part of this migration):
--
--   drop policy if exists "gym_attendance_delete_own" on public.gym_attendance;
--   drop policy if exists "gym_attendance_update_own" on public.gym_attendance;
--   drop policy if exists "gym_attendance_insert_own" on public.gym_attendance;
--   drop policy if exists "gym_attendance_select_own" on public.gym_attendance;
--   drop policy if exists "gyms_delete_own" on public.gyms;
--   drop policy if exists "gyms_update_own" on public.gyms;
--   drop policy if exists "gyms_insert_own" on public.gyms;
--   drop policy if exists "gyms_select_own" on public.gyms;
--   drop table if exists public.gym_attendance;
--   drop table if exists public.gyms;
-- ============================================================================
