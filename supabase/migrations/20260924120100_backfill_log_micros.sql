-- One-time data fix (2026-09-24, applied live via Management API): logs
-- written before the micro-nutrient plumbing was fixed (chiefly assigned
-- meals, which logged with extras=null) get their micros backfilled from
-- the foods catalog, scaled by the calories ratio — the same factor the
-- logged macros represent against the catalog row, so client-edited
-- quantities and substitutions stay proportional.
--
-- Guard: only rows where EVERY micro column is NULL are touched, so AI /
-- manual rows that already carry values are never overwritten. Idempotent.
UPDATE nutrition_logs l
SET
  fiber_g       = round(f.fiber_g       * (l.calories / f.calories), 1),
  sugars_g      = round(f.sugars_g      * (l.calories / f.calories), 1),
  sodium_mg     = round(f.sodium_mg     * (l.calories / f.calories)),
  potassium_mg  = round(f.potassium_mg  * (l.calories / f.calories)),
  calcium_mg    = round(f.calcium_mg    * (l.calories / f.calories)),
  iron_mg       = round(f.iron_mg       * (l.calories / f.calories), 1),
  cholesterol_mg = round(f.cholesterol_mg * (l.calories / f.calories)),
  caffeine_mg   = round(f.caffeine_mg   * (l.calories / f.calories), 1)
FROM foods f
WHERE f.id = l.food_id
  AND l.calories > 0
  AND f.calories > 0
  AND l.fiber_g IS NULL
  AND l.sugars_g IS NULL
  AND l.sodium_mg IS NULL
  AND l.potassium_mg IS NULL
  AND l.calcium_mg IS NULL
  AND l.iron_mg IS NULL
  AND l.cholesterol_mg IS NULL
  AND l.caffeine_mg IS NULL;

-- Recompute daily_summary micros from the (now complete) logs so the
-- ADDITIONAL NUTRIENTS displays pick the backfilled values immediately.
UPDATE daily_summary ds
SET
  fiber_g        = round(a.fiber, 1),
  sugars_g       = round(a.sugars, 1),
  sodium_mg      = round(a.sodium),
  potassium_mg   = round(a.potassium),
  calcium_mg     = round(a.calcium),
  iron_mg        = round(a.iron, 1),
  cholesterol_mg = round(a.cholesterol),
  caffeine_mg    = round(a.caffeine, 1),
  updated_at     = now()
FROM (
  SELECT
    user_id,
    logged_date,
    sum(coalesce(fiber_g, 0))        AS fiber,
    sum(coalesce(sugars_g, 0))       AS sugars,
    sum(coalesce(sodium_mg, 0))      AS sodium,
    sum(coalesce(potassium_mg, 0))   AS potassium,
    sum(coalesce(calcium_mg, 0))     AS calcium,
    sum(coalesce(iron_mg, 0))        AS iron,
    sum(coalesce(cholesterol_mg, 0)) AS cholesterol,
    sum(coalesce(caffeine_mg, 0))    AS caffeine
  FROM nutrition_logs
  GROUP BY user_id, logged_date
) a
WHERE ds.user_id = a.user_id
  AND ds.summary_date = a.logged_date;
