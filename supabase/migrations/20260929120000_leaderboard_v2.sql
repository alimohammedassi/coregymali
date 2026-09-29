-- ─────────────────────────────────────────────────────────────────────────
-- Leaderboard v2 — competitive hub backend (2026-09-29)
--
-- Extends the 60/40 commitment board (20260911120000_rank_leaderboard.sql)
-- WITHOUT changing it: existing get_leaderboard / get_user_activity /
-- day_commitment_score stay exactly as they are.
--
-- Adds:
--   user_window_scores(start, end)  per-user scores for one exact window
--   user_day_values(start, end)     per-user-per-day component values
--   get_leaderboard_v2(category, days, target, limit)
--       one-shot board payload: entries (rank, delta, 7-day trend, streaks)
--       + the calling user's full standing (rank, next target, adherence)
--   get_weekly_recap(days)          last Fri..Thu cycle top 3
--   get_rank_history(target, days)  target's rank per day (7-day window)
--   get_user_streak(target)         effective current + longest streak
--
-- Categories: overall | calories | water | workouts | streak | longest_streak
-- rank_delta > 0 means the user IMPROVED (previous_rank - current_rank).
-- Streaks REUSE the existing user_streaks / streak_activity_log system
-- (record_daily_activity); nothing is recomputed here. The stored
-- current_streak is only "effective" while the user is still alive per that
-- system's own rules (logged today/yesterday, or a pending freeze).
-- ─────────────────────────────────────────────────────────────────────────

-- Per-user scores for one exact window [p_start, p_end].
-- Population = users with at least one nutrition log in the window.
create or replace function public.user_window_scores(p_start date, p_end date)
returns table (
  user_id uuid,
  name text,
  avatar_url text,
  days_logged int,
  overall numeric,
  calories numeric,
  water numeric,
  workouts int
)
language sql stable security definer set search_path = public as $$
  with window_days as (
    select generate_series(p_start, p_end, interval '1 day')::date as d
  ),
  active_users as (
    select distinct ds.user_id
    from daily_summary ds
    where ds.summary_date between p_start and p_end
  ),
  per_user_day as (
    select
      au.user_id,
      wd.d,
      ds.calories_consumed,
      ds.water_ml,
      ds.workout_done,
      g.daily_calories,
      g.daily_water_ml
    from active_users au
    cross join window_days wd
    left join daily_summary ds
      on ds.user_id = au.user_id and ds.summary_date = wd.d
    left join user_goals g on g.user_id = au.user_id
  )
  select
    pud.user_id,
    coalesce(nullif(p.name, ''), 'Client') as name,
    p.avatar_url,
    count(*) filter (where pud.calories_consumed is not null or pud.water_ml is not null)::int as days_logged,
    round(avg(public.day_commitment_score(
      pud.calories_consumed, pud.daily_calories, pud.water_ml, pud.daily_water_ml)) * 100)::numeric as overall,
    round(avg(case
      when pud.calories_consumed is null or pud.calories_consumed <= 0 then 0
      else least(1, greatest(0,
        1 - abs(pud.calories_consumed - coalesce(pud.daily_calories, 2000))
            / greatest(coalesce(pud.daily_calories, 2000), 1)))
    end) * 100)::numeric as calories,
    round(avg(least(1, greatest(0,
      coalesce(pud.water_ml, 0) / greatest(coalesce(pud.daily_water_ml, 2500), 1)))) * 100)::numeric as water,
    count(*) filter (where pud.workout_done)::int as workouts
  from per_user_day pud
  join profiles p on p.id = pud.user_id
  where coalesce(p.role::text, 'client') <> 'coach'
  group by pud.user_id, p.name, p.avatar_url;
$$;

-- Per-user-per-day component values (0..100 each) for trend sparklines.
-- One row per daily_summary entry; missing days are filled with 0 by the caller.
create or replace function public.user_day_values(p_start date, p_end date)
returns table (
  user_id uuid,
  d date,
  overall numeric,
  calories numeric,
  water numeric,
  workout numeric
)
language sql stable security definer set search_path = public as $$
  select
    ds.user_id,
    ds.summary_date as d,
    round(public.day_commitment_score(
      ds.calories_consumed, g.daily_calories, ds.water_ml, g.daily_water_ml) * 100)::numeric as overall,
    round(case
      when ds.calories_consumed is null or ds.calories_consumed <= 0 then 0
      else least(1, greatest(0,
        1 - abs(ds.calories_consumed - coalesce(g.daily_calories, 2000))
            / greatest(coalesce(g.daily_calories, 2000), 1)))
    end * 100)::numeric as calories,
    round(least(1, greatest(0,
      coalesce(ds.water_ml, 0) / greatest(coalesce(g.daily_water_ml, 2500), 1))) * 100)::numeric as water,
    case when coalesce(ds.workout_done, false) then 100 else 0 end::numeric as workout
  from daily_summary ds
  left join user_goals g on g.user_id = ds.user_id
  where ds.summary_date between p_start and p_end;
$$;

-- One-shot board payload for the competitive hub screen.
create or replace function public.get_leaderboard_v2(
  p_category text default 'overall',
  p_days int default 7,
  p_target uuid default null,
  p_limit int default 50
) returns json
language sql stable security definer set search_path = public as $$
  with params as (
    select
      coalesce(p_category, 'overall') as cat,
      greatest(1, least(coalesce(p_days, 7), 30)) as days,
      coalesce(p_target, auth.uid()) as target,
      greatest(1, least(coalesce(p_limit, 50), 100)) as lim,
      current_date as cur_end,
      current_date - (greatest(1, least(coalesce(p_days, 7), 30)) - 1) as cur_start
  ),
  bounds as (
    select
      p.*,
      p.cur_start - 1 as prev_end,
      p.cur_start - p.days as prev_start,
      p.cat in ('streak', 'longest_streak') as is_streak
    from params p
  ),
  -- Unified board population: current-window users ∪ streak users.
  board as (
    select
      coalesce(s.user_id, us.user_id) as user_id,
      coalesce(nullif(p.name, ''), 'Client') as name,
      p.avatar_url,
      coalesce(s.days_logged, 0)::int as days_logged,
      s.overall,
      s.calories,
      s.water,
      coalesce(s.workouts, 0)::int as workouts,
      coalesce(us.current_streak, 0)::int as raw_streak,
      coalesce(us.longest_streak, 0)::int as longest_streak,
      us.last_active_date,
      coalesce(us.freeze_available, 0)::int as freeze_available
    from public.user_window_scores(
      (select cur_start from bounds), (select cur_end from bounds)) s
    full outer join public.user_streaks us on us.user_id = s.user_id
    join profiles p on p.id = coalesce(s.user_id, us.user_id)
    where coalesce(p.role::text, 'client') <> 'coach'
  ),
  board_cur as (
    select
      b.user_id, b.name, b.avatar_url,
      b.days_logged, b.overall, b.calories, b.water, b.workouts,
      b.raw_streak, b.longest_streak, b.last_active_date, b.freeze_available,
      -- effective current streak, per record_daily_activity semantics:
      -- alive if active today/yesterday, or yesterday-1 with a pending freeze
      case
        when b.raw_streak > 0
             and b.last_active_date >= (select cur_end from bounds) - 2
             and (b.last_active_date >= (select cur_end from bounds) - 1
                  or coalesce(b.freeze_available, 0) > 0)
        then b.raw_streak else 0
      end::int as eff_streak
    from board b
  ),
  scored as (
    select
      bc.*,
      case (select cat from bounds)
        when 'overall' then bc.overall
        when 'calories' then bc.calories
        when 'water' then bc.water
        when 'workouts' then bc.workouts::numeric
        when 'streak' then bc.eff_streak::numeric
        when 'longest_streak' then bc.longest_streak::numeric
      end as cat_value
    from board_cur bc
  ),
  ranked as (
    select
      s.*,
      row_number() over (
        order by s.cat_value desc nulls last,
                 case when (select is_streak from bounds)
                      then s.longest_streak else s.days_logged end desc nulls last,
                 s.days_logged desc nulls last,
                 s.user_id
      )::int as rank
    from scored s
    where case (select cat from bounds)
            when 'workouts' then s.workouts > 0
            when 'streak' then s.cat_value > 0
            when 'longest_streak' then s.cat_value > 0
            else s.days_logged > 0
          end
  ),
  top as (
    select * from ranked order by rank limit (select lim from bounds)
  ),
  -- Previous-cycle ranks (same category, window shifted back by p_days).
  prev_board as (
    select
      coalesce(s.user_id, us.user_id) as user_id,
      coalesce(s.days_logged, 0)::int as days_logged,
      case (select cat from bounds)
        when 'overall' then s.overall
        when 'calories' then s.calories
        when 'water' then s.water
        when 'workouts' then s.workouts::numeric
        when 'streak' then greatest(
          case
            when us.last_active_date = (select cur_end from bounds)
              then coalesce(us.current_streak, 0) - 1
            when us.last_active_date = (select cur_end from bounds) - 1
              then coalesce(us.current_streak, 0)
            else 0
          end, 0)::numeric
        when 'longest_streak' then (
          case
            when us.last_active_date = (select cur_end from bounds)
                 and us.current_streak = us.longest_streak and us.current_streak > 0
              then coalesce(us.longest_streak, 0) - 1
            else coalesce(us.longest_streak, 0)
          end)::numeric
      end as prev_value
    from public.user_window_scores(
      (select prev_start from bounds), (select prev_end from bounds)) s
    full outer join public.user_streaks us on us.user_id = s.user_id
    join profiles p on p.id = coalesce(s.user_id, us.user_id)
    where coalesce(p.role::text, 'client') <> 'coach'
  ),
  prev_ranked as (
    select pb.user_id,
           row_number() over (
             order by pb.prev_value desc nulls last,
                      pb.days_logged desc,
                      pb.user_id
           )::int as prev_rank
    from prev_board pb
    where case (select cat from bounds)
            when 'workouts' then pb.prev_value > 0
            when 'streak' then pb.prev_value > 0
            when 'longest_streak' then pb.prev_value > 0
            else pb.days_logged > 0
          end
  ),
  -- 7-day per-day component pivot (missing days = 0) for the sparklines.
  trend as (
    select
      b.user_id,
      array_agg(coalesce(td.overall, 0)::int order by gs.d) as overall_t,
      array_agg(coalesce(td.calories, 0)::int order by gs.d) as cal_t,
      array_agg(coalesce(td.water, 0)::int order by gs.d) as water_t,
      array_agg(coalesce(td.workout, 0)::int order by gs.d) as workout_t,
      array_agg(case when sal.user_id is not null then 100 else 0 end order by gs.d) as active_t
    from board_cur b
    cross join (
      select generate_series::date as d from generate_series(
        (select cur_end from bounds) - 6, (select cur_end from bounds), interval '1 day')
    ) gs
    left join public.user_day_values(
      (select cur_end from bounds) - 6, (select cur_end from bounds)) td
      on td.user_id = b.user_id and td.d = gs.d
    left join public.streak_activity_log sal
      on sal.user_id = b.user_id and sal.activity_date = gs.d
    group by b.user_id
  ),
  trend_sel as (
    select user_id,
      case (select cat from bounds)
        when 'overall' then overall_t
        when 'calories' then cal_t
        when 'water' then water_t
        when 'workouts' then workout_t
        else active_t
      end as t
    from trend
  ),
  entries as (
    select jsonb_agg(jsonb_build_object(
        'user_id', t.user_id,
        'name', t.name,
        'avatar_url', t.avatar_url,
        'rank', t.rank,
        'score', t.cat_value::int,
        'days_logged', t.days_logged,
        'rank_delta', case when pr.prev_rank is null then null else pr.prev_rank - t.rank end,
        'trend', tr.t,
        'current_streak', t.eff_streak,
        'longest_streak', t.longest_streak
      ) order by t.rank) as arr
    from top t
    left join prev_ranked pr on pr.user_id = t.user_id
    left join trend_sel tr on tr.user_id = t.user_id
  ),
  me as (
    select r.*, tr.t as my_trend, pr.prev_rank as my_prev_rank
    from ranked r
    left join prev_ranked pr on pr.user_id = r.user_id
    left join trend_sel tr on tr.user_id = r.user_id
    where r.user_id = (select target from bounds)
  ),
  me_json as (
    select case
      when m.user_id is null then null
      else jsonb_build_object(
        'user_id', m.user_id,
        'name', m.name,
        'avatar_url', m.avatar_url,
        'rank', m.rank,
        'total', (select count(*) from ranked)::int,
        'score', m.cat_value::int,
        'days_logged', m.days_logged,
        'rank_delta', case when m.my_prev_rank is null then null else m.my_prev_rank - m.rank end,
        'trend', m.my_trend,
        'current_streak', m.eff_streak,
        'longest_streak', m.longest_streak,
        'cal_adherence', coalesce(m.calories, 0)::int,
        'water_adherence', coalesce(m.water, 0)::int,
        'next_user', nu.name,
        'next_rank', nu.rank,
        'next_score', nu.cat_value::int,
        'points_to_next', greatest(nu.cat_value - m.cat_value, 0)::int
      )
    end as obj
    from me m
    left join ranked nu on nu.rank = m.rank - 1
  )
  select json_build_object(
    'category', (select cat from bounds),
    'days', (select days from bounds),
    'period_start', (select cur_start from bounds),
    'period_end', (select cur_end from bounds),
    'entries', (select arr from entries),
    'me', (select obj from me_json)
  );
$$;

-- Top 3 of the previous Fri..Thu cycle (overall commitment).
create or replace function public.get_weekly_recap(p_days int default 7)
returns json
language sql stable security definer set search_path = public as $$
  with cycle as (
    select
      (current_date - ((extract(dow from current_date)::int - 5 + 7) % 7))::date as cycle_start,
      greatest(1, least(coalesce(p_days, 7), 30)) as days
  ),
  w as (
    select
      cycle_start - days as prev_start,
      cycle_start - 1 as prev_end
    from cycle
  )
  select json_build_object(
    'period_start', w.prev_start,
    'period_end', w.prev_end,
    'entries', (
      select jsonb_agg(jsonb_build_object(
          'user_id', s.user_id,
          'name', s.name,
          'avatar_url', s.avatar_url,
          'score', s.overall::int
        ) order by s.overall desc, s.days_logged desc)
      from (
        select * from public.user_window_scores(w.prev_start, w.prev_end)
        order by overall desc, days_logged desc
        limit 3
      ) s
    )
  )
  from w;
$$;

-- The target's rank at the end of each of the last p_days days,
-- ranked by the rolling 7-day overall score as of that day.
create or replace function public.get_rank_history(p_target uuid, p_days int default 30)
returns table (history_date date, rank int, total int, score int)
language sql stable security definer set search_path = public as $$
  with days as (
    select generate_series(
      current_date - (least(greatest(coalesce(p_days, 30), 1), 30) - 1),
      current_date,
      interval '1 day')::date as d
  ),
  per_day as (
    select
      gs.d,
      s.user_id,
      s.overall,
      row_number() over (
        partition by gs.d
        order by s.overall desc, s.days_logged desc, s.user_id
      )::int as rank,
      count(*) over (partition by gs.d)::int as total
    from days gs
    cross join lateral public.user_window_scores(gs.d - 6, gs.d) s
  )
  select
    pd.d as history_date,
    pd.rank,
    pd.total,
    coalesce(pd.overall, 0)::int as score
  from per_day pd
  where pd.user_id = p_target
  order by pd.d;
$$;

-- Effective streak state for any user (same liveness rule as the board).
create or replace function public.get_user_streak(p_target uuid)
returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'current_streak',
      case
        when us.current_streak > 0
             and us.last_active_date >= current_date - 2
             and (us.last_active_date >= current_date - 1
                  or coalesce(us.freeze_available, 0) > 0)
        then us.current_streak else 0
      end,
    'longest_streak', coalesce(us.longest_streak, 0),
    'last_active_date', us.last_active_date
  )
  from public.user_streaks us
  where us.user_id = p_target;
$$;

-- Authenticated-only access, mirroring the existing rank functions.
revoke execute on function public.user_window_scores(date, date) from public, anon;
revoke execute on function public.user_day_values(date, date) from public, anon;
revoke execute on function public.get_leaderboard_v2(text, int, uuid, int) from public, anon;
revoke execute on function public.get_weekly_recap(int) from public, anon;
revoke execute on function public.get_rank_history(uuid, int) from public, anon;
revoke execute on function public.get_user_streak(uuid) from public, anon;
grant execute on function public.user_window_scores(date, date) to authenticated;
grant execute on function public.user_day_values(date, date) to authenticated;
grant execute on function public.get_leaderboard_v2(text, int, uuid, int) to authenticated;
grant execute on function public.get_weekly_recap(int) to authenticated;
grant execute on function public.get_rank_history(uuid, int) to authenticated;
grant execute on function public.get_user_streak(uuid) to authenticated;
