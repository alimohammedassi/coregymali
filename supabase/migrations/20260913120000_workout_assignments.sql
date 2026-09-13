-- ============================================================================
-- Workout assignment contract — REFERENCE ONLY, DO NOT APPLY.
-- The dashboard engineer's own migration created these tables in prod on
-- 2026-09-13 (with a `coaches` table + their own RLS). This file is kept
-- only as the client app's read-model documentation. Two client-read RLS
-- policies in the live migration had join typos (wt_client_read compared
-- a.template_id = a.id; wte_client_read compared a.template_id to itself)
-- — fixed live on 2026-09-13; the dashboard engineer should fold the
-- corrected predicates into their migration source:
--   wt_client_read:  exists (select 1 from workout_assignments a
--                             where a.template_id = workout_templates.id
--                               and a.client_id = auth.uid())
--   wte_client_read: exists (select 1 from workout_assignments a
--                             where a.template_id =
--                                   workout_template_exercises.template_id
--                               and a.client_id = auth.uid())
--
-- Read model used by the app:
--   workout_assignments(client_id = auth.uid(), scheduled_date = today,
--                       status in ('assigned','started'))
--     JOIN workout_templates (name, target_muscles, notes)
--     JOIN workout_template_exercises ORDER BY order_index
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.workout_templates (
  id             uuid primary key default gen_random_uuid(),
  coach_id       uuid not null references public.profiles(id) on delete cascade,
  name           text not null,
  target_muscles text[] not null default '{}',
  notes          text,
  created_at     timestamptz not null default now()
);

create table if not exists public.workout_template_exercises (
  id              uuid primary key default gen_random_uuid(),
  template_id     uuid not null references public.workout_templates(id) on delete cascade,
  exercise_name   text not null,
  target_sets     int,
  target_reps     int,
  target_weight_kg numeric,
  rest_sec        int,
  notes           text,
  order_index     int not null default 0
);

create table if not exists public.workout_assignments (
  id             uuid primary key default gen_random_uuid(),
  template_id    uuid not null references public.workout_templates(id) on delete cascade,
  coach_id       uuid references public.profiles(id),
  client_id      uuid not null references public.profiles(id) on delete cascade,
  program_id     uuid,
  scheduled_date date not null,
  status         text not null default 'assigned'
                 check (status in ('assigned','started','completed','skipped')),
  created_at     timestamptz not null default now()
);

-- Link column on the existing logging table (nullable; sessions logged by
-- other flows simply have NULL here).
alter table public.workout_sessions
  add column if not exists assignment_id uuid references public.workout_assignments(id)
  on delete set null;

create index if not exists workout_assignments_client_date_idx
  on public.workout_assignments (client_id, scheduled_date);
create index if not exists workout_template_exercises_order_idx
  on public.workout_template_exercises (template_id, order_index);
create index if not exists workout_sessions_assignment_idx
  on public.workout_sessions (assignment_id);

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.workout_templates enable row level security;
alter table public.workout_template_exercises enable row level security;
alter table public.workout_assignments enable row level security;

-- Clients must read the joined template + exercises of their assignment.
drop policy if exists "templates readable by authenticated" on public.workout_templates;
create policy "templates readable by authenticated" on public.workout_templates
  for select to authenticated using (true);

drop policy if exists "template exercises readable by authenticated" on public.workout_template_exercises;
create policy "template exercises readable by authenticated" on public.workout_template_exercises
  for select to authenticated using (true);

-- Coach manages templates (dashboard).
drop policy if exists "coach manages own templates" on public.workout_templates;
create policy "coach manages own templates" on public.workout_templates
  for all to authenticated using (coach_id = auth.uid()) with check (coach_id = auth.uid());

drop policy if exists "coach manages own template exercises" on public.workout_template_exercises;
create policy "coach manages own template exercises" on public.workout_template_exercises
  for all to authenticated
  using (exists (select 1 from public.workout_templates t where t.id = template_id and t.coach_id = auth.uid()))
  with check (exists (select 1 from public.workout_templates t where t.id = template_id and t.coach_id = auth.uid()));

-- Client reads + progresses own assignments ('started'/'completed' are set
-- by the app); coach reads/creates/updates (dashboard).
drop policy if exists "client reads own assignments" on public.workout_assignments;
create policy "client reads own assignments" on public.workout_assignments
  for select to authenticated using (client_id = auth.uid());

drop policy if exists "client updates own assignment status" on public.workout_assignments;
create policy "client updates own assignment status" on public.workout_assignments
  for update to authenticated
  using (client_id = auth.uid()) with check (client_id = auth.uid());

drop policy if exists "coach manages client assignments" on public.workout_assignments;
create policy "coach manages client assignments" on public.workout_assignments
  for all to authenticated using (coach_id = auth.uid()) with check (coach_id = auth.uid());
