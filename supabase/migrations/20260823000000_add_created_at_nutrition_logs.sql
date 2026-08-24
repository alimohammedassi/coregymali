-- Add created_at to nutrition_logs (fixes error 42703: column does not exist)
ALTER TABLE public.nutrition_logs
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- Keep daily_summary.updated_at behavior consistent if desired (no-op here)
