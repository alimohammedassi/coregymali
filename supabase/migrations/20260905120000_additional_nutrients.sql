-- ═══════════════════════════════════════════════════════════════════════════
-- Additional Nutrients pipeline (TASK 3)
-- Adds fiber / sugars / sodium / potassium / calcium / iron / cholesterol /
-- caffeine columns to every table on the food-logging path.
--
-- Semantics:
--   • Catalog / staging / log tables: columns are NULLABLE with NO default.
--     NULL means "unknown" (the source didn't provide it) — never 0.
--   • daily_summary: NOT NULL DEFAULT 0 — it stores aggregates, so a day with
--     no micro-nutrient data sums to a clean 0 rather than NULL.
--
-- RLS notes:
--   • nutrition_logs and daily_summary already have owner-based policies
--     (see 20240322_fix_rls.sql: SELECT/INSERT/UPDATE/DELETE WHERE
--     auth.uid() = user_id). Column-level RLS does not exist here; new
--     columns inherit their table's policies automatically, so no new
--     policies are needed. The verification block below is a no-op guard
--     that only re-enables RLS / re-creates policies if they were dropped.
--   • foods is PUBLIC-READ BY DESIGN: policy "Anyone can view foods"
--     USING (true) lets signed-out onboarding flows browse the catalog.
--     Writes stay authenticated ("Authenticated users can insert foods").
--     Unchanged here.
--   • barcode_products is a shared public-read cache by design (same pattern
--     as foods) — it is filled by the lookup-barcode Edge Function with the
--     service-role key, not by clients.
--   • food_scan_items / voice_food_log_items are staging tables created from
--     the dashboard (not present in this migrations dir) — hence the
--     IF NOT EXISTS / DO-block guards everywhere below.
--
-- REVIEW ONLY — do not apply from the app session. The owner applies this
-- via the Supabase dashboard/CLI after review.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. foods catalog ────────────────────────────────────────────────────────
ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS fiber_g        numeric,
  ADD COLUMN IF NOT EXISTS sugars_g       numeric,
  ADD COLUMN IF NOT EXISTS sodium_mg      numeric,
  ADD COLUMN IF NOT EXISTS potassium_mg   numeric,
  ADD COLUMN IF NOT EXISTS calcium_mg     numeric,
  ADD COLUMN IF NOT EXISTS iron_mg        numeric,
  ADD COLUMN IF NOT EXISTS cholesterol_mg numeric,
  ADD COLUMN IF NOT EXISTS caffeine_mg    numeric;

-- ── 2. nutrition_logs (per-log values) ──────────────────────────────────────
ALTER TABLE public.nutrition_logs
  ADD COLUMN IF NOT EXISTS fiber_g        numeric,
  ADD COLUMN IF NOT EXISTS sugars_g       numeric,
  ADD COLUMN IF NOT EXISTS sodium_mg      numeric,
  ADD COLUMN IF NOT EXISTS potassium_mg   numeric,
  ADD COLUMN IF NOT EXISTS calcium_mg     numeric,
  ADD COLUMN IF NOT EXISTS iron_mg        numeric,
  ADD COLUMN IF NOT EXISTS cholesterol_mg numeric,
  ADD COLUMN IF NOT EXISTS caffeine_mg    numeric;

-- ── 3. daily_summary (aggregates) ───────────────────────────────────────────
ALTER TABLE public.daily_summary
  ADD COLUMN IF NOT EXISTS fiber_g        numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sugars_g       numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sodium_mg      numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS potassium_mg   numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS calcium_mg     numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS iron_mg        numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cholesterol_mg numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS caffeine_mg    numeric NOT NULL DEFAULT 0;

-- ── 4. food_scan_items (AI-scan staging) ────────────────────────────────────
ALTER TABLE public.food_scan_items
  ADD COLUMN IF NOT EXISTS fiber_g        numeric,
  ADD COLUMN IF NOT EXISTS sugars_g       numeric,
  ADD COLUMN IF NOT EXISTS sodium_mg      numeric,
  ADD COLUMN IF NOT EXISTS potassium_mg   numeric,
  ADD COLUMN IF NOT EXISTS calcium_mg     numeric,
  ADD COLUMN IF NOT EXISTS iron_mg        numeric,
  ADD COLUMN IF NOT EXISTS cholesterol_mg numeric,
  ADD COLUMN IF NOT EXISTS caffeine_mg    numeric;

-- ── 5. voice_food_log_items (voice staging) ─────────────────────────────────
ALTER TABLE public.voice_food_log_items
  ADD COLUMN IF NOT EXISTS fiber_g        numeric,
  ADD COLUMN IF NOT EXISTS sugars_g       numeric,
  ADD COLUMN IF NOT EXISTS sodium_mg      numeric,
  ADD COLUMN IF NOT EXISTS potassium_mg   numeric,
  ADD COLUMN IF NOT EXISTS calcium_mg     numeric,
  ADD COLUMN IF NOT EXISTS iron_mg        numeric,
  ADD COLUMN IF NOT EXISTS cholesterol_mg numeric,
  ADD COLUMN IF NOT EXISTS caffeine_mg    numeric;

-- ── 6. barcode_products (shared per-100g cache) ─────────────────────────────
ALTER TABLE public.barcode_products
  ADD COLUMN IF NOT EXISTS fiber_g        numeric,
  ADD COLUMN IF NOT EXISTS sugars_g       numeric,
  ADD COLUMN IF NOT EXISTS sodium_mg      numeric,
  ADD COLUMN IF NOT EXISTS potassium_mg   numeric,
  ADD COLUMN IF NOT EXISTS calcium_mg     numeric,
  ADD COLUMN IF NOT EXISTS iron_mg        numeric,
  ADD COLUMN IF NOT EXISTS cholesterol_mg numeric,
  ADD COLUMN IF NOT EXISTS caffeine_mg    numeric;

-- ── 7. RLS verification (idempotent guard — no-op when intact) ──────────────
-- Owner policies for these two tables already exist from 20240322_fix_rls.sql.
-- The block below only repairs them if someone dropped RLS/policies later.
DO $$
BEGIN
  -- nutrition_logs
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'nutrition_logs' AND c.relrowsecurity
  ) THEN
    ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'nutrition_logs'
      AND policyname = 'Users can view own data'
  ) THEN
    CREATE POLICY "Users can view own data" ON public.nutrition_logs
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'nutrition_logs'
      AND policyname = 'Users can insert own data'
  ) THEN
    CREATE POLICY "Users can insert own data" ON public.nutrition_logs
      FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'nutrition_logs'
      AND policyname = 'Users can update own data'
  ) THEN
    CREATE POLICY "Users can update own data" ON public.nutrition_logs
      FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'nutrition_logs'
      AND policyname = 'Users can delete own data'
  ) THEN
    CREATE POLICY "Users can delete own data" ON public.nutrition_logs
      FOR DELETE USING (auth.uid() = user_id);
  END IF;

  -- daily_summary
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'daily_summary' AND c.relrowsecurity
  ) THEN
    ALTER TABLE public.daily_summary ENABLE ROW LEVEL SECURITY;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'daily_summary'
      AND policyname = 'Users can view own data'
  ) THEN
    CREATE POLICY "Users can view own data" ON public.daily_summary
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'daily_summary'
      AND policyname = 'Users can insert own data'
  ) THEN
    CREATE POLICY "Users can insert own data" ON public.daily_summary
      FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'daily_summary'
      AND policyname = 'Users can update own data'
  ) THEN
    CREATE POLICY "Users can update own data" ON public.daily_summary
      FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'daily_summary'
      AND policyname = 'Users can delete own data'
  ) THEN
    CREATE POLICY "Users can delete own data" ON public.daily_summary
      FOR DELETE USING (auth.uid() = user_id);
  END IF;
END
$$;

-- foods: intentionally public-read (see header). No policy changes.
-- food_scan_items / voice_food_log_items / barcode_products: created outside
-- this migrations dir; verify their RLS in the dashboard before applying:
--   SELECT tablename, rowsecurity FROM pg_tables
--   WHERE schemaname='public'
--     AND tablename IN ('food_scan_items','voice_food_log_items','barcode_products');
