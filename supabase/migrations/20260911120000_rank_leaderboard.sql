-- ─────────────────────────────────────────────────────────────────────────
-- Rank / Leaderboard system (2026-09-11)
-- Commitment score: 60% calorie adherence + 40% water adherence over a
-- rolling window. Days with no logs count as 0 (logging daily IS commitment).
-- Coaches are excluded from the board; only authenticated users can call.
-- ─────────────────────────────────────────────────────────────────────────

-- Shared per-day commitment score (0..1)
create or replace function public.day_commitment_score(
  p_consumed numeric,
  p_calorie_goal numeric,
  p_water_ml numeric,
  p_water_goal numeric
) returns numeric
language sql immutable as $$
  select
    0.6 * least(1, greatest(0,
      case
        when p_consumed is null or p_consumed <= 0 then 0
        else 1 - abs(p_consumed - coalesce(p_calorie_goal, 2000))
             / greatest(coalesce(p_calorie_goal, 2000), 1)
      end))
    + 0.4 * least(1, greatest(0,
      coalesce(p_water_ml, 0) / greatest(coalesce(p_water_goal, 2500), 1)));
$$;

-- Leaderboard: ranked clients over the last p_days days
create or replace function public.get_leaderboard(p_days int default 7)
returns table (
  user_id uuid,
  name text,
  avatar_url text,
  score int,
  days_logged int,
  avg_calories numeric,
  avg_water_ml numeric
)
language sql stable security definer set search_path = public as $$
  with window_days as (
    select generate_series(
      current_date - (p_days - 1),
      current_date,
      interval '1 day')::date as d
  ),
  active_users as (
    select distinct user_id
    from daily_summary
    where summary_date >= current_date - (p_days - 1)
  ),
  per_user_day as (
    select
      au.user_id,
      wd.d,
      ds.calories_consumed,
      ds.water_ml,
      g.daily_calories,
      g.daily_water_ml
    from active_users au
    cross join window_days wd
    left join daily_summary ds
      on ds.user_id = au.user_id and ds.summary_date = wd.d
    left join user_goals g on g.user_id = au.user_id
  ),
  scored as (
    select
      user_id,
      count(*) filter (where calories_consumed is not null or water_ml is not null) as days_logged,
      avg(public.day_commitment_score(
        calories_consumed, daily_calories, water_ml, daily_water_ml)) as avg_score,
      avg(coalesce(calories_consumed, 0)) as avg_calories,
      avg(coalesce(water_ml, 0)) as avg_water_ml
    from per_user_day
    group by user_id
  )
  select
    s.user_id,
    coalesce(nullif(p.name, ''), 'Client') as name,
    p.avatar_url,
    round(s.avg_score * 100)::int as score,
    s.days_logged::int,
    round(s.avg_calories, 0) as avg_calories,
    round(s.avg_water_ml, 0) as avg_water_ml
  from scored s
  join profiles p on p.id = s.user_id
  where coalesce(p.role::text, 'client') <> 'coach'
    and s.days_logged > 0
  order by score desc, days_logged desc
  limit 50;
$$;

-- One client's daily activity for the profile page charts/heatmap
create or replace function public.get_user_activity(
  p_target uuid,
  p_days int default 30
)
returns table (
  summary_date date,
  calories_consumed numeric,
  calorie_goal int,
  water_ml numeric,
  water_goal int,
  steps int,
  steps_goal int,
  workout_done boolean,
  day_score int
)
language sql stable security definer set search_path = public as $$
  select
    ds.summary_date,
    coalesce(ds.calories_consumed, 0),
    coalesce(g.daily_calories, 2000),
    coalesce(ds.water_ml, 0),
    coalesce(g.daily_water_ml, 2500),
    coalesce(ds.steps, 0),
    coalesce(g.daily_steps, 8000),
    coalesce(ds.workout_done, false),
    round(public.day_commitment_score(
      ds.calories_consumed, g.daily_calories, ds.water_ml, g.daily_water_ml) * 100)::int
  from daily_summary ds
  left join user_goals g on g.user_id = ds.user_id
  where ds.user_id = p_target
    and ds.summary_date >= current_date - (p_days - 1)
  order by ds.summary_date;
$$;

-- Only signed-in users can call these
revoke execute on function public.get_leaderboard(int) from public, anon;
revoke execute on function public.get_user_activity(uuid, int) from public, anon;
grant execute on function public.get_leaderboard(int) to authenticated;
grant execute on function public.get_user_activity(uuid, int) to authenticated;
